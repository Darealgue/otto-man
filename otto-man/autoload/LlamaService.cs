using Godot;
using System;
using System.Text; // Required for Encoding, StringBuilder
using System.Threading.Tasks;
using System.Threading;
using System.IO; // Add this for Path operations
using System.Collections.Generic; // Added for List
using System.Linq;
using System.Runtime.InteropServices; // For P/Invoke
using System.Runtime.CompilerServices;

// <<< Add LLamaSharp usings >>>
using LLama.Abstractions;
using LLama;
using LLama.Common;
using LLama.Exceptions;
using LLama.Native;
using LLama.Sampling;
using LLama.Transformers;
using LLama.Extensions;

using SamplingGrammar = LLama.Sampling.Grammar;

// Win32 API for short path conversion + CUDA DLL load search order (Godot + LLamaSharp CPU fallback)
internal static class NativeMethods
{
	/// <summary>
	/// With an absolute <c>lpFileName</c>, dependent DLL search includes the folder containing that DLL <b>and</b> directories on <c>PATH</c>
	/// (standard alternate search order). This differs from <see cref="NativeLibrary.Load"/> on recent .NET, which often uses
	/// <c>LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS</c> — that path does <b>not</b> search <c>PATH</c> for dependents,
	/// so NVIDIA <c>cudart64_12.dll</c> next to the toolkit never resolves unless we preload with this flag (or copy CUDA DLLs next to <c>llama.dll</c>).
	/// </summary>
	internal const uint LOAD_WITH_ALTERED_SEARCH_PATH = 0x00000008;

	[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
	internal static extern int GetShortPathName(
		[MarshalAs(UnmanagedType.LPTStr)] string path,
		[MarshalAs(UnmanagedType.LPTStr)] StringBuilder shortPath,
		int shortPathLength);

	/// <summary>Makes Windows resolve dependent DLLs (e.g. <c>cudart64_*.dll</c>) from this folder when loading <c>llama.dll</c>.</summary>
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	[return: MarshalAs(UnmanagedType.Bool)]
	internal static extern bool SetDllDirectory(string lpPathName);

	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	internal static extern IntPtr LoadLibraryEx(string lpLibFileName, IntPtr hFile, uint dwFlags);
}

/// <summary>
/// On-device inference via LLamaSharp for OttoMan. High-level module map and player-visible JSON rules live in
/// <c>grammars/dev_session_prompt.txt</c>.
/// <para><b>NPC output shape:</b> Godot strips leading junk then parses JSON. The model should emit one object with keys
/// <c>Info</c>, <c>History</c>, and <c>Generated Dialogue</c> (space required), matching <c>grammars/output.gbnf</c>.
/// When that matches, <c>NPCDialogueManager</c> significance merge and state persistence behave unchanged.</para>
/// <para><b>Grammar:</b> GBNF can be loaded for constrained sampling, but the NPC dialogue path usually disables it at runtime
/// (native sampler crash with some tokenizer stacks). Prompt + logit bias toward “<c>{</c>” still anchor JSON.</para>
/// <para><b>Chat format:</b> Mistral-7B-Instruct uses <see cref="WrapMistralInstruct"/> ([INST] wrapping).</para>
/// <para><b>NPC weights:</b> NPC dialogue always uses the same BASE GGUF as everything else (Mistral-NeMo). The prior merged-GGUF/LoRA
/// experiment (a separate fine-tune baked for Mistral-7B) has been removed — those model files are gone and won't be used again.</para>
/// <para><b>NPC dialogue decode:</b> Defaults to <b>synchronous</b> chunked <c>LLamaContext.Decode</c> (see <see cref="InferNpcUsingSharedContext"/>).
/// LLamaSharp’s <see cref="StatelessExecutor.InferAsync"/> prefills with <c>DecodeAsync</c>; inside Godot that often stalls idle-GPU on long NPC prompts while BASE/shorter jobs still look fine — same weights, different scheduler path.
/// <b>VROOM / InferAsync:</b> set <c>OTTO_LLAMA_VROOM=1</c> or <c>OTTO_NPC_USE_INFER_ASYNC=1</c> so NPC matches BASE’s InferAsync (fans may spin when it works; may hang when it doesn’t).
/// Sync tuning: <c>OTTO_NPC_PREFILL_CHUNK</c> (32–4096; larger = fewer batches but bigger wedge risk).</para>
/// <para><b>Diagnostics:</b> In the editor, set <see cref="LogNpcInferGodotDiagnostics"/> or env <c>OTTO_LLAMA_VERBOSE=1</c> for native llama logs, thread IDs, InferAsync milestones, and prefill batch summaries.</para>
/// </summary>
public partial class LlamaService : Node, IDisposable
{
	/// <summary>Base GGUF filename under <c>res://models/</c>. Switched from Mistral-7B to Mistral-NeMo-12B-Instruct
	/// (Apache-2.0, same [INST] chat format as Mistral-7B — WrapMistralInstruct needs no changes) after 7B hit a
	/// reasoning ceiling on TP1 significance (same-fact-vs-new-fact discrimination) that prompt/grammar/logit-bias
	/// tuning could not clear. See docs/MODEL_UPGRADE_GUIDE.md.</summary>
	private static readonly string DefaultModelFileName = "Mistral-Nemo-Instruct-2407-Q4_K_M.gguf";

	// --- TP1 (spoken dialogue) anti-repetition sampling (applied ONLY to three-pass pass 1) ---
	// Stops the NPC from echoing its own previous line once that line is in the chat-history context.
	// Keep mild so in-character vocabulary survives; raise RepeatPenalty / FrequencyPenalty if loops persist.
	private const float NpcDialogueRepeatPenalty = 1.18f;
	private const float NpcDialogueFrequencyPenalty = 0.85f;
	private const float NpcDialoguePresencePenalty = 0.5f;
	// Must be large enough to include the previous NPC line (which sits behind the instruction block).
	private const int NpcDialoguePenaltyCount = 256;

	/// <summary>
	/// Default prefill chunk cap for NPC sync inference (<see cref="InferNpcUsingSharedContext"/>).
	/// Very large chunks (e.g. 512) can wedge on some stacks — use env <c>OTTO_NPC_PREFILL_CHUNK</c> to tune (32–4096).
	/// </summary>
	private static readonly int NpcStatelessInferPrefillChunkTokens = 128;

	private static int NpcInferThreadCount => Math.Clamp(System.Environment.ProcessorCount, 4, 32);

	private static bool NpcUseFlashAttention =>
		!string.Equals(System.Environment.GetEnvironmentVariable("OTTO_LLAMA_NO_FLASH"), "1", StringComparison.OrdinalIgnoreCase);

	/// <summary>
	/// Extra verbose BEFORE/AFTER lines per batch (debug only).
	/// </summary>
	private static readonly bool LogNpcPrefillChunkProgress = false;

	/// <summary>
	/// One-line progress per prefill batch. Lots of <see cref="GD.Print"/> while CUDA runs can add jitter in-editor — leave false unless debugging wedges.
	/// When <see cref="VerboseInferLogs"/> is true (editor or <c>OTTO_LLAMA_VERBOSE=1</c>), batch summaries are logged anyway.
	/// </summary>
	private static readonly bool LogNpcPrefillBatchSummaryAlways = false;

	/// <summary>
	/// When true, the editor run enables richer inference tracing (native backend lines, thread IDs, InferAsync milestones, prefill batch lines).
	/// Exported games: set env <c>OTTO_LLAMA_VERBOSE=1</c> instead.
	/// </summary>
	private static readonly bool LogNpcInferGodotDiagnostics = false;

	/// <summary>
	/// When true, logs a single structured line per generation with timings and token estimates (Godot output).
	/// Flip to false to reduce console noise in shipped builds.
	/// </summary>
	private static readonly bool LogInferenceMetrics = false;

	/// <summary>
	/// When true, prints <c>[LlamaStep +Nms]</c> lines through NPC runtime LoRA inference (verbose).
	/// </summary>
	private static readonly bool LogLlamaInferenceSteps = false;

	[MethodImpl(MethodImplOptions.AggressiveInlining)]
	private static void LlamaStep(System.Diagnostics.Stopwatch inferWallClock, string message)
	{
		if (!LogLlamaInferenceSteps)
			return;
		long ms = inferWallClock.ElapsedMilliseconds;
		GD.Print($"[LlamaStep +{ms}ms tid={System.Threading.Thread.CurrentThread.ManagedThreadId}] {message}");
	}

	private static bool VerboseInferLogs()
	{
		if (string.Equals(System.Environment.GetEnvironmentVariable("OTTO_LLAMA_VERBOSE"), "1", StringComparison.Ordinal))
			return true;
		return LogNpcInferGodotDiagnostics && Engine.IsEditorHint();
	}

	/// <summary>Prefill chunk for NPC sync path; env <c>OTTO_NPC_PREFILL_CHUNK</c> when set to an integer in [32, 4096].</summary>
	private static int ResolveNpcPrefillChunkTokens()
	{
		string e = System.Environment.GetEnvironmentVariable("OTTO_NPC_PREFILL_CHUNK") ?? "";
		if (string.IsNullOrWhiteSpace(e))
			return NpcStatelessInferPrefillChunkTokens;
		if (!int.TryParse(e.Trim(), System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture, out int n))
			return NpcStatelessInferPrefillChunkTokens;
		if (n < 32 || n > 4096)
			return NpcStatelessInferPrefillChunkTokens;
		return n;
	}

	/// <summary>
	/// LLamaSharp 0.24: <see cref="NativeLibraryConfig.All.DryRun"/> before <see cref="LLamaWeights.LoadFromFile"/> usually returns false with null libraries — not a disk/CUDA layout failure.
	/// Real CUDA vs CPU signal comes from <see cref="LogLlamaCppSystemInfoAfterNativeReady"/> after weights load.
	/// </summary>
	private static void LogLlamaBackendProbeNoteBeforeLoad()
	{
		GD.Print(
			"LlamaService: LLamaSharp 0.24 — ignoring pre-load NativeLibraryConfig.All.DryRun (unreliable until native init); "
			+ "see llama.cpp system line after model load.");
	}

	private static void LogLlamaCppSystemInfoAfterNativeReady()
	{
		try
		{
			IntPtr p = NativeApi.llama_print_system_info();
			if (p == IntPtr.Zero)
			{
				GD.PushWarning("LlamaService: llama_print_system_info returned IntPtr.Zero.");
				return;
			}

			string s = Marshal.PtrToStringUTF8(p);
			if (string.IsNullOrWhiteSpace(s))
				GD.PushWarning("LlamaService: llama_print_system_info produced empty string.");
			else
			{
				string trimmed = s.TrimEnd();
				GD.Print($"LlamaService: llama.cpp system info —\n{trimmed}");
				if (!LlamaSystemInfoLooksCudaCapable(trimmed))
				{
					GD.PrintErr(
						"LlamaService: loaded llama.cpp is CPU-only (no CUDA/Vulkan line above). GpuLayerCount does not use your RTX GPU. "
						+ "Ensure NVIDIA CUDA 12.x toolkit \\bin is visible (cudart64_12.dll); restart Godot after fixing PATH. "
						+ "OTTO_LLAMA_VERBOSE=1 for loader logs. OTTO_LLAMA_USE_SETDLLDIR=1 opts into SetDllDirectory (usually unnecessary).");
				}
			}
		}
		catch (Exception ex)
		{
			GD.PushWarning($"LlamaService: llama_print_system_info failed: {ex.Message}");
		}
	}

	private static bool LlamaSystemInfoLooksCudaCapable(string info)
	{
		if (string.IsNullOrEmpty(info))
			return false;
		string u = info.ToUpperInvariant();
		return u.Contains("CUDA", StringComparison.Ordinal)
			   || u.Contains("CUBLAS", StringComparison.Ordinal)
			   || u.Contains("GGML_CUDA", StringComparison.Ordinal)
			   || u.Contains("HIP", StringComparison.Ordinal)
			   || u.Contains("VULKAN", StringComparison.Ordinal)
			   || u.Contains("METAL", StringComparison.Ordinal);
	}

	private static void LogManagedInferDllProbePaths()
	{
		try
		{
			string loc = typeof(LlamaService).Assembly.Location;
			if (!string.IsNullOrEmpty(loc))
				GD.Print($"LlamaService: managed DLL folder (native runtime probe root): {Path.GetDirectoryName(loc)}");
		}
		catch (Exception ex)
		{
			GD.PushWarning($"LlamaService: probe paths: {ex.Message}");
		}
	}

	private static string ResolveWindowsLlamaCuda12NativeDirOrNull()
	{
		if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
			return null;

		var candidates = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
		void TryAddDir(string dir)
		{
			if (string.IsNullOrEmpty(dir))
				return;
			try
			{
				candidates.Add(Path.GetFullPath(dir));
			}
			catch
			{
				/* ignore */
			}
		}

		string gameLoc = typeof(LlamaService).Assembly.Location;
		if (!string.IsNullOrEmpty(gameLoc))
			TryAddDir(Path.GetDirectoryName(gameLoc));

		try
		{
			string lwLoc = typeof(LLamaWeights).Assembly.Location;
			if (!string.IsNullOrEmpty(lwLoc))
				TryAddDir(Path.GetDirectoryName(lwLoc));
		}
		catch
		{
			/* ignore */
		}

		TryAddDir(AppContext.BaseDirectory);

		foreach (string root in candidates)
		{
			string cuda12 = Path.Combine(root, "runtimes", "win-x64", "native", "cuda12");
			try
			{
				cuda12 = Path.GetFullPath(cuda12);
			}
			catch
			{
				continue;
			}

			if (Directory.Exists(cuda12))
				return cuda12;
		}

		return null;
	}

	private static void LogWindowsCuda12ResolutionProbe()
	{
		if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
			return;
		string gameLoc = typeof(LlamaService).Assembly.Location;
		string lwLoc = "";
		try { lwLoc = typeof(LLamaWeights).Assembly.Location ?? ""; }
		catch { /* ignore */ }
		string cuda12 = ResolveWindowsLlamaCuda12NativeDirOrNull();
		GD.Print($"LlamaService: Windows CUDA probe — LlamaService.Assembly.Location=\"{gameLoc}\"");
		GD.Print($"LlamaService: Windows CUDA probe — LLamaWeights.Assembly.Location=\"{lwLoc}\"");
		GD.Print($"LlamaService: Windows CUDA probe — AppContext.BaseDirectory=\"{AppContext.BaseDirectory}\"");
		GD.Print($"LlamaService: Windows CUDA probe — resolved cuda12 dir: {(cuda12 ?? "(null)")}");
		string toolkitBin = ResolveWindowsNvidiaCudaToolkitBinOrNull();
		GD.Print($"LlamaService: Windows CUDA probe — NVIDIA toolkit bin (cudart): {(toolkitBin ?? "(null)")}");
	}

	private static string ResolveWindowsNvidiaCudaToolkitBinOrNull()
	{
		if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
			return null;

		string cudaVar = System.Environment.GetEnvironmentVariable("CUDA_PATH");
		if (!string.IsNullOrWhiteSpace(cudaVar))
		{
			string bin = Path.Combine(cudaVar.Trim().TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar), "bin");
			try
			{
				bin = Path.GetFullPath(bin);
			}
			catch
			{
				bin = null;
			}

			if (!string.IsNullOrEmpty(bin) && File.Exists(Path.Combine(bin, "cudart64_12.dll")))
				return bin;
		}

		try
		{
			const string toolkitRoot = @"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA";
			if (!Directory.Exists(toolkitRoot))
				return null;

			string[] versionDirs = Directory.GetDirectories(toolkitRoot, "v12.*");
			Array.Sort(versionDirs, StringComparer.OrdinalIgnoreCase);
			for (int i = versionDirs.Length - 1; i >= 0; i--)
			{
				string bin = Path.Combine(versionDirs[i], "bin");
				if (File.Exists(Path.Combine(bin, "cudart64_12.dll")))
					return Path.GetFullPath(bin);
			}
		}
		catch
		{
			/* ignore */
		}

		return null;
	}

	private static void TryPrependOrderedDirsToProcessPath(System.Collections.Generic.IReadOnlyList<string> dirs)
	{
		if (dirs == null || dirs.Count == 0)
			return;
		try
		{
			string pathVar = System.Environment.GetEnvironmentVariable("PATH") ?? "";
			var uniq = new System.Collections.Generic.List<string>();
			foreach (string d in dirs)
			{
				if (string.IsNullOrEmpty(d) || !Directory.Exists(d))
					continue;
				string full = Path.GetFullPath(d);
				bool dup = false;
				foreach (string u in uniq)
				{
					if (string.Equals(u, full, StringComparison.OrdinalIgnoreCase))
					{
						dup = true;
						break;
					}
				}

				if (!dup)
					uniq.Add(full);
			}

			if (uniq.Count == 0)
				return;

			foreach (string full in uniq)
			{
				string needle = full + Path.PathSeparator;
				if (pathVar.StartsWith(needle, StringComparison.OrdinalIgnoreCase))
					continue;
				int idx = pathVar.IndexOf(needle, StringComparison.OrdinalIgnoreCase);
				if (idx >= 0)
				{
					string left = idx > 0 ? pathVar.Substring(0, idx).TrimEnd(Path.PathSeparator) : "";
					string right = pathVar.Substring(idx + needle.Length).TrimStart(Path.PathSeparator);
					pathVar = string.IsNullOrEmpty(left)
						? right
						: string.IsNullOrEmpty(right)
							? left
							: left + Path.PathSeparator + right;
				}

				pathVar = needle + pathVar.TrimStart(Path.PathSeparator);
			}

			System.Environment.SetEnvironmentVariable("PATH", pathVar);
			GD.Print($"LlamaService: prepended PATH — {string.Join(" ; ", uniq)}");
		}
		catch (Exception ex)
		{
			GD.PushWarning($"LlamaService: PATH prepend failed: {ex.Message}");
		}
	}

	/// <summary>CPU backend dispatcher (<c>ggml.dll</c>) loads <c>ggml-cpu.dll</c> + <c>ggml-cuda.dll</c>; order avoids Win32 126.</summary>
	private static readonly string[] SCuda12PreloadDependencyOrder =
	{
		"ggml-base.dll",
		"ggml-cpu.dll",
		"ggml-cuda.dll",
		"ggml.dll",
	};

	private static IntPtr TryWindowsLoadLibraryAlteredSearchPath(string absolutePath, string labelForLog)
	{
		IntPtr h = NativeMethods.LoadLibraryEx(absolutePath, IntPtr.Zero, NativeMethods.LOAD_WITH_ALTERED_SEARCH_PATH);
		if (h != IntPtr.Zero)
			return h;
		int err = Marshal.GetLastWin32Error();
		GD.PrintErr($"LlamaService: LoadLibraryEx FAILED ({labelForLog}) — win32={err} — {absolutePath}");
		return IntPtr.Zero;
	}

	private static void TryPreloadWindowsCuda12LlamaDll(string cuda12Dir)
	{
		if (cuda12Dir == null || !RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
			return;
		if (string.Equals(System.Environment.GetEnvironmentVariable("OTTO_LLAMA_SKIP_NATIVE_PRELOAD"), "1", StringComparison.OrdinalIgnoreCase))
			return;
		string llamaPath = Path.Combine(cuda12Dir, "llama.dll");
		if (!File.Exists(llamaPath))
		{
			GD.PushWarning($"LlamaService: preload skipped — missing {llamaPath}");
			return;
		}

		// Load CUDA stack with PATH-aware dependency resolution so toolkit bin (cudart/cublas) is visible.
		foreach (string dep in SCuda12PreloadDependencyOrder)
		{
			string depPath = Path.Combine(cuda12Dir, dep);
			if (!File.Exists(depPath))
				continue;
			if (TryWindowsLoadLibraryAlteredSearchPath(depPath, dep) == IntPtr.Zero)
			{
				GD.PrintErr(
					"LlamaService: CUDA native preload stopped early — CUDA toolkit bin on PATH (cudart/cublas); "
					+ "ggml.dll needs ggml-cpu.dll from LLamaSharp.Backend.Cpu (rebuild copies avx2 ggml-cpu into native/cuda12); "
					+ "install VC++ 2015–2022 x64 if MSVC runtime is missing.");
				return;
			}
		}

		IntPtr hAltered = TryWindowsLoadLibraryAlteredSearchPath(llamaPath, "llama.dll");
		if (hAltered != IntPtr.Zero)
		{
			GD.Print($"LlamaService: LoadLibraryEx OK (LOAD_WITH_ALTERED_SEARCH_PATH) — {llamaPath} (handle={hAltered})");
			return;
		}

		try
		{
			IntPtr h = NativeLibrary.Load(llamaPath);
			GD.Print($"LlamaService: NativeLibrary.Load OK (fallback) — {llamaPath} (handle={h})");
		}
		catch (Exception ex)
		{
			GD.PrintErr($"LlamaService: NativeLibrary.Load FAILED — {llamaPath} — {ex.Message}");
			GD.PrintErr(
				"LlamaService: missing DLL dependency — prepend NVIDIA CUDA toolkit \\bin (contains cudart64_12.dll) to PATH before cuda12; "
				+ ".NET NativeLibrary.Load often skips PATH for dependents; LOAD_WITH_ALTERED_SEARCH_PATH preload failed first — check win32 errors above.");
		}
	}

	/// <summary>
	/// Prepends NVIDIA CUDA toolkit <c>bin</c> (cudart/cublas) then bundled <c>cuda12</c> natives. <see cref="NativeMethods.SetDllDirectory"/> is opt-in — default off — because it can block resolving <c>cudart</c> from Program Files.
	/// </summary>
	private static void TryConfigureWindowsCuda12NativeLoadingBeforeLlamaLoad()
	{
		if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
			return;

		LogWindowsCuda12ResolutionProbe();

		string cuda12 = ResolveWindowsLlamaCuda12NativeDirOrNull();
		if (cuda12 == null)
		{
			GD.PrintErr(
				"LlamaService: runtimes/win-x64/native/cuda12 not found next to game or LLamaSharp DLL — rebuild C# (dotnet build) so NuGet copies runtimes.");
			return;
		}

		string toolkitBin = ResolveWindowsNvidiaCudaToolkitBinOrNull();
		var pathOrder = new System.Collections.Generic.List<string>();
		if (!string.IsNullOrEmpty(toolkitBin))
			pathOrder.Add(toolkitBin);
		pathOrder.Add(cuda12);
		TryPrependOrderedDirsToProcessPath(pathOrder);

		bool useDllDir =
			string.Equals(System.Environment.GetEnvironmentVariable("OTTO_LLAMA_USE_SETDLLDIR"), "1", StringComparison.OrdinalIgnoreCase)
			&& !string.Equals(System.Environment.GetEnvironmentVariable("OTTO_LLAMA_SKIP_SETDLLDIR"), "1", StringComparison.OrdinalIgnoreCase);
		if (useDllDir)
		{
			if (!NativeMethods.SetDllDirectory(cuda12))
			{
				int err = Marshal.GetLastWin32Error();
				GD.PushWarning($"LlamaService: SetDllDirectory failed (win32={err}) for {cuda12}");
			}
			else
				GD.Print($"LlamaService: SetDllDirectory → {cuda12} (OTTO_LLAMA_USE_SETDLLDIR=1)");
		}

		TryPreloadWindowsCuda12LlamaDll(cuda12);
	}

	/// <summary>InferAsync path like BASE summaries — env <c>OTTO_LLAMA_VROOM=1</c> or <c>OTTO_NPC_USE_INFER_ASYNC=1</c>.</summary>
	private static bool PreferNpcInferAsyncVroom()
	{
		if (string.Equals(System.Environment.GetEnvironmentVariable("OTTO_LLAMA_VROOM"), "1", StringComparison.OrdinalIgnoreCase))
			return true;
		if (string.Equals(System.Environment.GetEnvironmentVariable("OTTO_NPC_USE_INFER_ASYNC"), "1", StringComparison.OrdinalIgnoreCase))
			return true;
		return false;
	}

	private static void LogLoadedModelParams(ModelParams p, string label)
	{
		if (p == null)
			return;
		GD.Print(
			$"LlamaService: {label} — GpuLayerCount={p.GpuLayerCount}, BatchSize={p.BatchSize}, Threads={p.Threads}, BatchThreads={p.BatchThreads}, "
			+ $"NoKqvOffload={p.NoKqvOffload}, MainGpu={p.MainGpu}");
	}

	private static bool LogPrefillBatchSummary =>
		LogNpcPrefillBatchSummaryAlways || VerboseInferLogs();

	private static bool LogPrefillChunkDecodeSteps =>
		LogNpcPrefillChunkProgress || string.Equals(System.Environment.GetEnvironmentVariable("OTTO_LLAMA_CHUNK_TRACE"), "1", StringComparison.Ordinal);

	// Signal emitted when generation is complete
	[Signal]
	public delegate void GenerationCompleteEventHandler(string result);

	// Separate signals so different systems don't race each other.
	[Signal]
	public delegate void GenerationCompleteBaseEventHandler(string result);
	[Signal]
	public delegate void GenerationCompleteNpcEventHandler(string result);

	// --- P/Invoke Declarations Removed --- 

	// --- Struct/Enum Definitions Removed ---

	// --- Class Members ---
	// <<< Native pointers removed, LLamaSharp objects will replace them >>>
	private bool _isInitialized = false;
	private bool _isDisposed = false;

	// <<< LLamaSharp model/context objects will be added here >>>
	private LLamaWeights _modelWeightsBase;
	private ModelParams _parametersBase;

	/// <summary>One context reused for NPC dialogue. Per-chat <c>CreateContext</c> was costing ~10–20s per 128-token prefill slice on RTX 3060-class GPUs.</summary>
	private LLamaContext _npcSharedInferContext;
	private LLamaWeights _npcSharedInferWeights;
	private readonly object _npcSharedInferLock = new object();

	// --- Godot Lifecycle --- 
	public override void _Ready()
	{
		base._Ready();
		GD.Print("LlamaService Autoload _Ready.");
		
		// Initialize: single shared BASE GGUF (Mistral-NeMo), used for both summaries and NPC dialogue.
		if (!Initialize(DefaultModelFileName))
		{
			GD.PrintErr("Failed to initialize LlamaService with model.");
		}
	}

	// --- Initialization and Cleanup (To be re-implemented with LLamaSharp) ---

	public bool Initialize(string modelFilename)
	{
		GD.Print($"LLamaService Initialize called with: {modelFilename}");
		if (_isInitialized) return true;
		if (_isDisposed)
		{
			GD.PrintErr("Initialize called on a disposed LlamaService instance.");
			return false;
		}

		try
		{
			TryConfigureWindowsCuda12NativeLoadingBeforeLlamaLoad();
			LogManagedInferDllProbePaths();
			LogLlamaBackendProbeNoteBeforeLoad();

			if (VerboseInferLogs())
			{
				try
				{
					NativeLibraryConfig.All.WithLogCallback((LLamaLogLevel level, string message) =>
						GD.Print($"[llama-native {level}] {message.TrimEnd()}"));
					GD.Print("LlamaService: native llama log callback enabled (editor diagnostics or OTTO_LLAMA_VERBOSE=1).");
				}
				catch (Exception logCbEx)
				{
					GD.PushWarning($"LlamaService: could not register native log callback: {logCbEx.Message}");
				}
			}

			// 1. Construct Model Path — BASE GGUF must exist on disk.
			string modelLoadPath;
			if (OS.HasFeature("editor"))
			{
				string projectRoot = ProjectSettings.GlobalizePath("res://");
				if (string.IsNullOrEmpty(projectRoot)) { throw new Exception("Failed to globalize project path res://"); }
				modelLoadPath = Path.Combine(projectRoot, "models", modelFilename);
				GD.Print($"Editor Mode: Model path: {modelLoadPath}");
			}
			else
			{
				string exePath = OS.GetExecutablePath();
				string exeDir = Path.GetDirectoryName(exePath);
				if (string.IsNullOrEmpty(exeDir)) { throw new Exception("Failed to get executable directory!"); }
				string packagedModelPath = Path.Combine(exeDir, "models", modelFilename);
				if (File.Exists(packagedModelPath))
				{
					modelLoadPath = packagedModelPath;
					GD.Print($"Exported Mode: Model path (packaged): {modelLoadPath}");
				}
				else
				{
					modelLoadPath = Path.Combine(exeDir, modelFilename);
					GD.Print($"Exported Mode: Model path: {modelLoadPath}");
				}

				if (!File.Exists(modelLoadPath))
				{
					string envDir = System.Environment.GetEnvironmentVariable("OTTO_MODEL_DIR");
					string fallbackDir = !string.IsNullOrWhiteSpace(envDir) ? envDir : "C:\\otto_exp";
					string fallbackPath = Path.Combine(fallbackDir, modelFilename);
					if (File.Exists(fallbackPath))
					{
						GD.Print($"Model not found in exe directory, using fallback path: {fallbackPath}");
						modelLoadPath = fallbackPath;
					}
				}
			}

			modelLoadPath = Path.GetFullPath(modelLoadPath);
			GD.Print($"Normalized model path: {modelLoadPath}");
			GD.Print($"Path length: {modelLoadPath.Length} characters");
			GD.Print($"Path exists: {File.Exists(modelLoadPath)}");

			if (!File.Exists(modelLoadPath))
				throw new Exception($"Model file not found at: {modelLoadPath}");

			try
			{
				var fileInfo = new FileInfo(modelLoadPath);
				GD.Print($"Model file size: {fileInfo.Length / (1024.0 * 1024.0 * 1024.0):F2} GB");
				GD.Print($"Model file readable: {fileInfo.IsReadOnly == false}");
			}
			catch (Exception ex)
			{
				GD.PrintErr($"Error checking model file: {ex.Message}");
			}

			modelLoadPath = ConvertToShortPathIfPossible(modelLoadPath);
			GD.Print($"Final BASE model path: {modelLoadPath}");

			// 2. ModelParams — one shared BASE GGUF for everything (summaries and NPC dialogue alike).
			// NPC prompts are long (duplicated JSON + rules). 4096 tokens is often exceeded → llama truncates / bad logits → single-token loops.
			const int contextSize = 16384;
			const int gpuLayers = 99;

			_parametersBase = new ModelParams(modelLoadPath)
			{
				ContextSize = contextSize,
				GpuLayerCount = gpuLayers,
				UseMemoryLock = false,
				UseMemorymap = true,
				Threads = NpcInferThreadCount,
				BatchThreads = NpcInferThreadCount,
				FlashAttention = NpcUseFlashAttention,
			};

			// 3. Load weights — one shared load, used for both BASE and NPC dialogue.
			GD.Print("Loading BASE model (Mistral-NeMo-Instruct)...");
			_modelWeightsBase = LLamaWeights.LoadFromFile(_parametersBase);
			GD.Print("BASE model ready. NPC dialogue shares these same weights (no merged GGUF / no LoRA).");

			if (_modelWeightsBase != null)
				LogLlamaCppSystemInfoAfterNativeReady();

			LogLoadedModelParams(_parametersBase, "Model params (active inference)");
			GD.Print(
				"LlamaService: NPC default = sync chunked Decode (stable in editor). "
				+ "VROOM / BASE-style path: env OTTO_LLAMA_VROOM=1 (same InferAsync as summaries; may idle-hang on long NPC prompts). "
				+ "Fewer sync batches: raise OTTO_NPC_PREFILL_CHUNK (max 512; wedge risk).");

			TryWarmNpcSharedContextAtStartup();

			// 6. Mark as Initialized
			_isInitialized = true;
			GD.Print("LlamaService Initialized Successfully (using LLamaSharp).");
			if (VerboseInferLogs())
				GD.Print("LlamaService diagnostics: native [llama-native …] lines + prefill batch summaries enabled in editor. Per-chunk BEFORE/AFTER: set env OTTO_LLAMA_CHUNK_TRACE=1. Toggle field LogNpcInferGodotDiagnostics to silence.");
			return true;
		}
		catch (Exception e)
		{
			GD.PrintErr($"LlamaService Initialization failed: {e.Message}");
			GD.PrintErr(e.StackTrace);
			CleanupNativeResources(); // Call new cleanup
			_isInitialized = false;
			return false;
		}
	}

	// Helper to check initialization status
	public bool IsInitialized() => _isInitialized;

	// --- Dispose Pattern (Will be updated for LLamaSharp objects) ---
	public new void Dispose() { Dispose(true); GC.SuppressFinalize(this); }
	protected override void Dispose(bool disposing)
	{
		if (_isDisposed) return;
		CleanupNativeResources(); // Call new cleanup
		_isDisposed = true;
		_isInitialized = false;
		base.Dispose(disposing); // Call base class dispose
	}
	~LlamaService() { Dispose(false); } // Finalizer

	private void CleanupNativeResources()
	{
		GD.Print("Cleaning up LLamaSharp resources...");
		try { _npcSharedInferContext?.Dispose(); }
		catch (Exception ex) { GD.PushWarning($"LlamaService NPC shared context dispose: {ex.Message}"); }
		_npcSharedInferContext = null;
		_npcSharedInferWeights = null;

		_modelWeightsBase?.Dispose();
		_modelWeightsBase = null;
		_parametersBase = null;
		GD.Print("LLamaSharp resources cleaned.");
	}

	// --- Async Wrapper (Remains mostly the same) ---
	public void GenerateResponseAsync(string prompt, int maxNewTokens = 350, bool useGrammar = true, float temperature = 0.8f)
	{
		GenerateResponseAsyncBase(prompt, maxNewTokens, useGrammar, temperature);
	}

	/// <summary>General model path (no LoRA). Use for summaries and non-NPC tasks.</summary>
	/// <param name="grammarFileName">File under <c>grammars/</c> (e.g. <c>battle_story.gbnf</c>). Empty = <c>output.gbnf</c> when <paramref name="useGrammar"/> is true — that's the legacy single-pass NPC JSON schema, almost never what a new BASE caller wants, so pass a filename explicitly.</param>
	/// <param name="appendJsonObjectOutputFooter">
	/// When true (default, back-compat), <see cref="WrapMistralInstruct"/> appends "Return ONLY the JSON object...
	/// Start with '{'" to any prompt that doesn't already carry its own [INST]...[/INST] envelope. Set false for
	/// plain-prose BASE callers (e.g. the battle-story summary) — otherwise the model is told to open with '{'
	/// in the SAME breath the prompt itself says "no JSON," and it follows the more explicit, more recent instruction.
	/// </param>
	public void GenerateResponseAsyncBase(string prompt, int maxNewTokens = 350, bool useGrammar = true, float temperature = 0.8f, string grammarFileName = "", bool appendJsonObjectOutputFooter = true)
	{
		if (!_isInitialized || _isDisposed)
		{
			GD.PrintErr("LlamaService not ready for GenerateResponseAsync.");
			EmitSignal(SignalName.GenerationComplete, "");
			return;
		}

		Task.Run(async () => {
			try {
				if (VerboseInferLogs())
					GD.Print($"LlamaService: BASE inference Task.Run entry tid={System.Threading.Thread.CurrentThread.ManagedThreadId}");
				string result = await GenerateResponse(prompt, maxNewTokens, useGrammar, temperature, useNpcModel:false, appendJsonObjectOutputFooter: appendJsonObjectOutputFooter, grammarFileName: grammarFileName).ConfigureAwait(false);
				if (VerboseInferLogs())
					GD.Print($"<<< RAW LLM RESULT >>>:\n{result}\n<<< END RAW LLM RESULT >>>");
				CallDeferred("emit_signal", SignalName.GenerationCompleteBase, result ?? "");
				// Backward compat: old listeners still get base results.
				CallDeferred("emit_signal", SignalName.GenerationComplete, result ?? "");
			}
			catch (Exception ex) { GD.PrintErr($"Async gen error: {ex.Message}\n{ex.StackTrace}"); CallDeferred("emit_signal", SignalName.GenerationComplete, ""); }
		});
	}

	/// <summary>
	/// NPC dialogue path: uses dedicated NPC weights when merged-GGUF or LoRA-adapter mode is enabled; otherwise the same base GGUF as summaries.
	/// When <paramref name="appendJsonObjectOutputFooter"/> is true (default), the Mistral wrapper asks for JSON-only output (single-pass / pass 2–3).
	/// Set it false for three-pass <b>pass 1</b> (plain dialogue line with <c>Generated dialogue:</c> prefix).
	/// </summary>
	/// <param name="grammarFileName">File under <c>grammars/</c> (e.g. <c>tp2_ledger.gbnf</c>). Empty = <c>output.gbnf</c> when <paramref name="useGrammar"/> is true.</param>
	public void GenerateResponseAsyncNpc(string prompt, int maxNewTokens = 350, bool useGrammar = true, float temperature = 0.8f, bool appendJsonObjectOutputFooter = true, string grammarFileName = "")
	{
		if (!_isInitialized || _isDisposed)
		{
			GD.PrintErr("LlamaService not ready for GenerateResponseAsyncNpc.");
			EmitSignal(SignalName.GenerationComplete, "");
			return;
		}

		// Same scheduling as <see cref="GenerateResponseAsyncBase"/>: threadpool <c>Task.Run(async …)</c> + <c>await GenerateResponse</c>.
		// NPC merged dialogue uses sync chunked <c>Decode</c> inside <c>GenerateResponse</c> (InferAsync/DecodeAsync wedges in Godot on long prompts).
		string capturePrompt = prompt;
		int captureMax = maxNewTokens;
		bool captureGrammar = useGrammar;
		float captureTemp = temperature;
		bool captureJsonFooter = appendJsonObjectOutputFooter;
		string captureGrammarFile = grammarFileName ?? "";

		Task.Run(async () =>
		{
			try
			{
				if (VerboseInferLogs())
					GD.Print($"LlamaService: NPC inference Task.Run entry tid={System.Threading.Thread.CurrentThread.ManagedThreadId}");
				string result = await GenerateResponse(capturePrompt, captureMax, captureGrammar, captureTemp, useNpcModel: true, appendJsonObjectOutputFooter: captureJsonFooter, grammarFileName: captureGrammarFile).ConfigureAwait(false);
				if (VerboseInferLogs())
					GD.Print($"<<< RAW LLM RESULT (NPC) >>>:\n{result}\n<<< END RAW LLM RESULT (NPC) >>>");
				CallDeferred("emit_signal", SignalName.GenerationCompleteNpc, result ?? "");
			}
			catch (Exception ex)
			{
				GD.PrintErr($"NPC async gen error: {ex.Message}\n{ex.StackTrace}");
				CallDeferred("emit_signal", SignalName.GenerationCompleteNpc, "");
				CallDeferred("emit_signal", SignalName.GenerationComplete, "");
			}
		});
	}

	// --- Core Inference (LLamaSharp in-process) ---

	private string LoadNpcGrammarContent(bool useGrammar, string grammarFileName = "")
	{
		if (!useGrammar)
			return "";

		string fileName = string.IsNullOrWhiteSpace(grammarFileName) ? "output.gbnf" : grammarFileName.Trim();

		// Same root as models/ — do NOT use GetBaseDir() on globalized res:// (that walks up one folder).
		string grammarDir;
		if (OS.HasFeature("editor"))
		{
			string projectRoot = ProjectSettings.GlobalizePath("res://");
			if (string.IsNullOrEmpty(projectRoot))
			{
				GD.PrintErr("Failed to globalize project path res:// for grammar.");
				return "";
			}
			grammarDir = Path.Combine(projectRoot, "grammars");
		}
		else
		{
			string exeDir = Path.GetDirectoryName(OS.GetExecutablePath());
			if (string.IsNullOrEmpty(exeDir))
			{
				GD.PrintErr("Failed to determine executable directory for grammar.");
				return "";
			}
			grammarDir = Path.Combine(exeDir, "grammars");
		}

		string grammarPath = Path.Combine(grammarDir, fileName);
		if (VerboseInferLogs())
			GD.Print($"Attempting to load grammar from: {grammarPath}");
		if (!File.Exists(grammarPath))
		{
			GD.PrintErr($"Grammar file not found at {grammarPath}");
			return "";
		}

		if (VerboseInferLogs())
			GD.Print($"Grammar file exists. Last modified: {new FileInfo(grammarPath).LastWriteTime}");
		string grammarContent = File.ReadAllText(grammarPath);
		return grammarContent.Replace("\r\n", "\n");
	}

	private async Task<string> GenerateResponse(string prompt, int maxNewTokens, bool useGrammar, float temperature, bool useNpcModel, bool appendJsonObjectOutputFooter = true, string grammarFileName = "")
	{
		if (!_isInitialized || _isDisposed)
		{
			GD.PrintErr("GenerateResponse: LlamaService not initialized or disposed.");
			return null;
		}

		// TP1 (three-pass spoken dialogue) is the only pass that benefits from anti-repetition penalties.
		// Detect it from the RAW prompt (TP2/TP3 carry their own [INST]...[/INST] envelope; TP1 does not)
		// BEFORE the wrap rewrites `prompt`. TP2 (field deltas) and TP3 (must faithfully echo history
		// facts) stay penalty-free so penalties never distort structured output.
		bool threePassDialogue = useNpcModel && !appendJsonObjectOutputFooter
			&& !prompt.Contains("[INST]", StringComparison.Ordinal);

		prompt = WrapMistralInstruct(prompt, appendJsonObjectOutputFooter);
		if (VerboseInferLogs())
			GD.Print("GenerateResponse: Mistral uses [INST] wrapper.");

		var weights = _modelWeightsBase;
		var parameters = _parametersBase;

		if (VerboseInferLogs() && useNpcModel)
			GD.Print("GenerateResponse: NPC uses the shared BASE GGUF (Mistral-NeMo) — no merged GGUF, no LoRA.");
		if (weights == null || parameters == null)
		{
			GD.PrintErr("GenerateResponse: LlamaService weights/parameters missing.");
			return null;
		}

		DefaultSamplingPipeline samplingPipeline = null;
		try
		{
			var prepWatch = System.Diagnostics.Stopwatch.StartNew();
			if (VerboseInferLogs())
				GD.Print("GenerateResponse: Starting LLamaSharp inference...");

			string grammarContent = LoadNpcGrammarContent(useGrammar, grammarFileName);
			if (!useGrammar)
			{
				if (VerboseInferLogs())
					GD.Print("Grammar disabled for this generation request.");
			}
			else if (string.IsNullOrEmpty(grammarContent))
				GD.PrintErr("Grammar content is empty, proceeding without grammar.");

			SamplingGrammar samplingGbnf = null;
			if (!string.IsNullOrEmpty(grammarContent))
			{
				try
				{
					samplingGbnf = new SamplingGrammar(grammarContent, "root");
					if (VerboseInferLogs())
						GD.Print("Grammar ready for sampling pipeline (GBNF root).");
				}
				catch (Exception grammarEx)
				{
					GD.PrintErr($"Failed to create sampling grammar: {grammarEx.Message}");
					GD.PrintErr(grammarEx.StackTrace);
					samplingGbnf = null;
				}
			}

			Dictionary<LLamaToken, float> npcLogitBias = null;
			// The '{' logit bias only helps the single-pass JSON path (appendJsonObjectOutputFooter=true).
			// The three-pass passes (TP1/TP2/TP3) were trained with NO brace bias (NpcDialogueDryRun RunInfer
			// useBraceBias=false); biasing toward '{' there pushes the model off its trained plain-text output.
			if (useNpcModel && appendJsonObjectOutputFooter)
			{
				try
				{
					var braceToks = weights.Tokenize("{", false, false, Encoding.UTF8);
					if (braceToks != null && braceToks.Length > 0)
					{
						npcLogitBias = new Dictionary<LLamaToken, float>
						{
							[braceToks[0]] = 6.0f
						};
						if (VerboseInferLogs())
							GD.Print("GenerateResponse: NPC LogitBias applied for '{' token.");
					}
				}
				catch (Exception lbx)
				{
					GD.PushWarning($"GenerateResponse: could not apply NPC LogitBias for '{{': {lbx.Message}");
				}
			}

			// NOTE: DefaultSamplingPipeline.LogitBias defaults to a non-null empty map; assigning null
			// (e.g. three-pass where no brace bias is used) makes CreateChain throw NullReferenceException.
			// LogitBias is init-only, so only include it in the initializer when we actually have one —
			// mirrors NpcDialogueDryRun RunInfer.
			if (npcLogitBias != null)
			{
				samplingPipeline = new DefaultSamplingPipeline
				{
					Temperature = temperature,
					Grammar = samplingGbnf,
					LogitBias = npcLogitBias,
				};
			}
			else if (threePassDialogue)
			{
				// Anti-repetition for spoken dialogue only. Without this the model copies its own
				// previous line verbatim once that line is sitting in the chat-history context.
				// PenaltyCount must reach back past the instruction block so the prior NPC line is in window.
				// No LogitBias here — the "Significant: yes/no" pick must never be nudged by the sampler,
				// only by prompt wording. See docs/PHILOSOPHY_REALISM_OVER_BIAS.md.
				samplingPipeline = new DefaultSamplingPipeline
				{
					Temperature = temperature,
					Grammar = samplingGbnf,
					RepeatPenalty = NpcDialogueRepeatPenalty,
					FrequencyPenalty = NpcDialogueFrequencyPenalty,
					PresencePenalty = NpcDialoguePresencePenalty,
					PenaltyCount = NpcDialoguePenaltyCount,
					PenalizeNewline = false,
				};
			}
			else
			{
				samplingPipeline = new DefaultSamplingPipeline
				{
					Temperature = temperature,
					Grammar = samplingGbnf,
				};
			}

			var inferenceParams = new InferenceParams
			{
				MaxTokens = maxNewTokens,
				AntiPrompts = Array.Empty<string>(),
				SamplingPipeline = samplingPipeline,
			};

			int promptTokCount = -1;
			try
			{
				var toks = weights.Tokenize(prompt, false, true, Encoding.UTF8);
				promptTokCount = toks.Length;
				int nCtx = (int)(parameters.ContextSize ?? 16384u);
				if (VerboseInferLogs())
				{
					GD.Print($"GenerateResponse: prompt token count={promptTokCount}, n_ctx={nCtx}, max_new_tokens={maxNewTokens}");
					if (promptTokCount + maxNewTokens > nCtx)
						GD.PrintErr($"GenerateResponse: prompt+max_new exceeds n_ctx ({promptTokCount}+{maxNewTokens}>{nCtx}) — raise ContextSize or shorten NPC prompt.");
					else if (promptTokCount > 3500)
						GD.Print($"GenerateResponse: long prompt ({promptTokCount} tokens); if you ever used n_ctx=4096 this would truncate badly.");
				}
				else if (promptTokCount + maxNewTokens > nCtx)
					GD.PrintErr($"GenerateResponse: prompt+max_new exceeds n_ctx ({promptTokCount}+{maxNewTokens}>{nCtx}) — raise ContextSize or shorten NPC prompt.");
			}
			catch (Exception tex)
			{
				GD.PushWarning($"GenerateResponse: could not count prompt tokens: {tex.Message}");
			}

			if (VerboseInferLogs())
			{
				GD.Print($"GenerateResponse: prompt debug preview only (first 280 chars of {prompt.Length} chars; NOT truncated for inference): {(prompt.Length > 280 ? prompt.Substring(0, 280) + "…" : prompt)}");
				GD.Print($"GenerateResponse: Infer about to start (useNpcModel={useNpcModel}, grammar={(samplingGbnf != null)}).");
			}

			prepWatch.Stop();
			long prepMs = prepWatch.ElapsedMilliseconds;

			var inferWatch = System.Diagnostics.Stopwatch.StartNew();
			long ttftMs = -1;
			int yieldChunks = 0;
			string result;

			if (useNpcModel)
			{
				if (PreferNpcInferAsyncVroom())
				{
					GD.PushWarning(
						"GenerateResponse: OTTO_LLAMA_VROOM / OTTO_NPC_USE_INFER_ASYNC — StatelessExecutor.InferAsync (DecodeAsync prefill). "
						+ "Same style as BASE summaries when it works; often idle-GPU stall on long NPC prompts in Godot — unset for default sync decode.");
					if (VerboseInferLogs())
						GD.Print($"GenerateResponse: NPC — VROOM InferAsync tid={System.Threading.Thread.CurrentThread.ManagedThreadId}");
					var executor = new StatelessExecutor(weights, parameters);
					var resultBuilder = new StringBuilder();
					if (VerboseInferLogs())
						GD.Print("GenerateResponse: NPC InferAsync — entering await foreach …");
					await foreach (var token_text in executor.InferAsync(prompt, inferenceParams, System.Threading.CancellationToken.None).ConfigureAwait(false))
					{
						if (yieldChunks == 0)
						{
							ttftMs = inferWatch.ElapsedMilliseconds;
							if (VerboseInferLogs())
								GD.Print($"GenerateResponse: NPC InferAsync — first yield after {inferWatch.ElapsedMilliseconds} ms");
						}
						yieldChunks++;
						resultBuilder.Append(token_text);
					}
					if (VerboseInferLogs())
						GD.Print($"GenerateResponse: NPC InferAsync — finished; yield_chunks={yieldChunks}");
					result = resultBuilder.ToString();
				}
				else
				{
					int npcChunk = ResolveNpcPrefillChunkTokens();
					string batchHint = "";
					if (promptTokCount >= 0 && npcChunk >= 32)
						batchHint = $", ~{(promptTokCount + npcChunk - 1) / npcChunk} prefill batches ({promptTokCount} prompt tokens)";
					if (VerboseInferLogs())
						GD.Print(
							$"GenerateResponse: NPC — SAFE sync chunked prefill (chunk≤{npcChunk}{batchHint}); "
							+ $"faster BASE-style try: OTTO_LLAMA_VROOM=1 (InferAsync; may idle-stall); tid={System.Threading.Thread.CurrentThread.ManagedThreadId}");
					int? prefillCap = npcChunk >= 32 ? npcChunk : null;
					(result, ttftMs, yieldChunks) = InferNpcUsingSharedContext(
						weights,
						parameters,
						prompt,
						inferenceParams,
						prefillCap,
						inferWatch,
						System.Threading.CancellationToken.None);
				}
			}
			else
			{
				if (VerboseInferLogs())
					GD.Print($"GenerateResponse: BASE — InferAsync tid={System.Threading.Thread.CurrentThread.ManagedThreadId}");
				var executor = new StatelessExecutor(weights, parameters);
				var resultBuilder = new StringBuilder();
				if (VerboseInferLogs())
					GD.Print("GenerateResponse: BASE InferAsync — entering await foreach …");
				await foreach (var token_text in executor.InferAsync(prompt, inferenceParams, System.Threading.CancellationToken.None).ConfigureAwait(false))
				{
					if (yieldChunks == 0)
					{
						ttftMs = inferWatch.ElapsedMilliseconds;
						if (VerboseInferLogs())
							GD.Print($"GenerateResponse: BASE InferAsync — first yield after {inferWatch.ElapsedMilliseconds} ms");
					}
					yieldChunks++;
					resultBuilder.Append(token_text);
				}
				if (VerboseInferLogs())
					GD.Print($"GenerateResponse: BASE InferAsync — finished; yield_chunks={yieldChunks}");
				result = resultBuilder.ToString();
			}

			inferWatch.Stop();
			long inferTotalMs = inferWatch.ElapsedMilliseconds;
			long afterFirstMs = ttftMs >= 0 ? inferTotalMs - ttftMs : inferTotalMs;

			int completionTokCount = -1;
			try
			{
				if (!string.IsNullOrEmpty(result))
				{
					var outToks = weights.Tokenize(result, false, false, Encoding.UTF8);
					completionTokCount = outToks.Length;
				}
				else
					completionTokCount = 0;
			}
			catch (Exception otx)
			{
				GD.PushWarning($"GenerateResponse: could not count completion tokens: {otx.Message}");
			}

			if (VerboseInferLogs())
				GD.Print($"GenerateResponse: LLamaSharp inference completed in {prepMs + inferTotalMs} ms (prep {prepMs} ms + infer {inferTotalMs} ms).");

			if (LogInferenceMetrics)
			{
				string pathTag = useNpcModel ? "npc" : "base";
				double avgMsPerOutTok = completionTokCount > 0 ? inferTotalMs / (double)completionTokCount : double.NaN;
				double incrDecodeMsPerTok = completionTokCount > 1 ? afterFirstMs / (double)(completionTokCount - 1) : double.NaN;
				string avgTokStr = double.IsNaN(avgMsPerOutTok) ? "n/a" : avgMsPerOutTok.ToString("F2");
				string incrTokStr = double.IsNaN(incrDecodeMsPerTok) ? "n/a" : incrDecodeMsPerTok.ToString("F2");
				string metricsLine =
					"[color=cyan][LlamaMetrics][/color] "
					+ $"path={pathTag} prompt_chars={prompt.Length} prompt_tokens={(promptTokCount >= 0 ? promptTokCount.ToString() : "?")} "
					+ $"completion_chars={result.Length} completion_tokens={(completionTokCount >= 0 ? completionTokCount.ToString() : "?")} "
					+ $"infer_yield_chunks={yieldChunks} max_new_tokens={maxNewTokens} grammar={(samplingGbnf != null ? "on" : "off")} "
					+ $"prep_ms={prepMs} infer_total_ms={inferTotalMs} ttft_ms={(ttftMs >= 0 ? ttftMs.ToString() : "n/a")} "
					+ $"after_first_ms={(ttftMs >= 0 ? afterFirstMs.ToString() : inferTotalMs.ToString())} "
					+ $"avg_ms_per_out_tok={avgTokStr} incr_decode_ms_per_tok={incrTokStr} "
					+ "| ttft_ms = prefill plus first piece; after_first_ms = rest of generation.";
				GD.PrintRich(metricsLine);
			}

			return result;
		}
		catch (Exception e)
		{
			GD.PrintErr($"GenerateResponse Error (LLamaSharp): {e.Message}");
			GD.PrintErr(e.StackTrace);
			return null;
		}
		finally
		{
			samplingPipeline?.Dispose();
		}
	}

	/// <summary>Build NPC dialogue GPU context once during startup so the first &quot;hello&quot; after Play does not pay full creation cost.</summary>
	private void TryWarmNpcSharedContextAtStartup()
	{
		if (_modelWeightsBase == null || _parametersBase == null)
			return;
		LLamaWeights w = _modelWeightsBase;
		IContextParams p = _parametersBase;

		try
		{
			lock (_npcSharedInferLock)
			{
				_npcSharedInferContext?.Dispose();
				_npcSharedInferContext = w.CreateContext(p, logger: null);
				_npcSharedInferWeights = w;
				_npcSharedInferContext.NativeHandle.KvCacheClear();
				TryMinimalGpuDecodeWarmup(_npcSharedInferContext);
				_npcSharedInferContext.NativeHandle.KvCacheClear();
			}

			if (VerboseInferLogs())
				GD.Print("LlamaService: NPC shared infer context warmed at startup — restart editor still pays this once; check llama.cpp system info for CUDA vs CPU.");
		}
		catch (Exception ex)
		{
			GD.PushWarning($"LlamaService: NPC GPU context warmup failed: {ex.Message}");
			_npcSharedInferContext = null;
			_npcSharedInferWeights = null;
		}
	}

	private static void TryMinimalGpuDecodeWarmup(LLamaContext ctx)
	{
		try
		{
			var toks = ctx.Tokenize(".", special: true).ToList();
			if (toks.Count == 0)
				return;
			var batch = new LLamaBatch();
			batch.Clear();
			batch.Add(toks[0], 0, LLamaSeqId.Zero, true);
			var rc = ctx.Decode(batch);
			if (rc == DecodeResult.Ok && VerboseInferLogs())
				GD.Print("LlamaService: NPC decode warmup finished (first llama_decode OK — if llama.cpp is CPU-only, this is still CPU work).");
			else
				GD.PushWarning($"LlamaService: NPC GPU decode warmup rc={rc}");
		}
		catch (Exception ex)
		{
			GD.PushWarning($"LlamaService: NPC GPU decode warmup skipped: {ex.Message}");
		}
	}

	/// <summary>NPC dialogue path: one long-lived <see cref="LLamaContext"/> (GPU stays hot). Memory between chats cleared via <see cref="SafeLLamaContextHandle.KvCacheClear"/>.</summary>
	private (string Result, long TtftMs, int YieldChunks) InferNpcUsingSharedContext(
		LLamaWeights weights,
		IContextParams contextParams,
		string prompt,
		IInferenceParams inferenceParams,
		int? prefillChunkCap,
		System.Diagnostics.Stopwatch inferWallClock,
		CancellationToken cancellationToken)
	{
		lock (_npcSharedInferLock)
		{
			if (_npcSharedInferContext == null || !ReferenceEquals(weights, _npcSharedInferWeights))
			{
				_npcSharedInferContext?.Dispose();
				_npcSharedInferContext = weights.CreateContext(contextParams, logger: null);
				_npcSharedInferWeights = weights;
				if (VerboseInferLogs())
					GD.Print("LlamaService: NPC shared GPU context created for this weights object (reuse until restart).");
				_npcSharedInferContext.NativeHandle.KvCacheClear();
				TryMinimalGpuDecodeWarmup(_npcSharedInferContext);
				_npcSharedInferContext.NativeHandle.KvCacheClear();
			}

			_npcSharedInferContext.NativeHandle.KvCacheClear();
			return InferStatelessDecodeCore(
				_npcSharedInferContext,
				weights,
				prompt,
				inferenceParams,
				prefillChunkCap,
				inferWallClock,
				cancellationToken);
		}
	}

	/// <summary>Chunked sync prefill + sampling loop (shared by runtime LoRA ephemeral contexts and NPC pooled context).</summary>
	private static (string Result, long TtftMs, int YieldChunks) InferStatelessDecodeCore(
		LLamaContext context,
		LLamaWeights weights,
		string prompt,
		IInferenceParams inferenceParams,
		int? prefillChunkCap,
		System.Diagnostics.Stopwatch inferWallClock,
		CancellationToken cancellationToken)
	{
		LlamaStep(inferWallClock, "infer core: SamplingPipeline.Reset");
		inferenceParams ??= new InferenceParams();
		inferenceParams.SamplingPipeline.Reset();

		if (inferenceParams.TokensKeep > context.ContextSize)
			throw new ArgumentOutOfRangeException(nameof(inferenceParams), $"TokensKeep ({inferenceParams.TokensKeep}) cannot be larger than ContextSize ({context.ContextSize})");

		LlamaStep(inferWallClock, "infer core: StreamingTokenDecoder + AntipromptProcessor");
		var decoder = new StreamingTokenDecoder(context);
		var antiprocessor = new AntipromptProcessor(inferenceParams.AntiPrompts);

		LlamaStep(inferWallClock, "infer core: Tokenize(prompt)");
		var tokens = context.Tokenize(prompt, special: true).ToList();
		LlamaStep(inferWallClock, $"infer core: Tokenize — {tokens.Count} tokens");

		var batch = new LLamaBatch();
		var n_past = 0;

		var batchSize = checked((int)context.BatchSize);
		if (prefillChunkCap is int cap && cap >= 32)
		{
			batchSize = Math.Min(batchSize, cap);
			LlamaStep(inferWallClock, $"infer core: prefill chunk cap — chunk={batchSize} (context.BatchSize={context.BatchSize})");
		}

		if (VerboseInferLogs())
			GD.Print($"GenerateResponse: stateless sync — prefill {tokens.Count} tokens in ~{(tokens.Count + batchSize - 1) / batchSize} batches (≤{batchSize} tokens/batch); first request may be slow while GPU warms up.");

		long prefillWallStartMs = inferWallClock.ElapsedMilliseconds;
		int totalPrefillBatches = (tokens.Count + batchSize - 1) / batchSize;
		int chunkIdx = 0;
		for (var i = 0; i < tokens.Count; i += batchSize)
		{
			var n_eval = tokens.Count - i;
			if (n_eval > batchSize)
				n_eval = batchSize;

			int nPastBeforeChunk = n_past;
			LlamaStep(inferWallClock, $"infer core: prefill chunk {chunkIdx} range=[{i},{i + n_eval}) n_past={nPastBeforeChunk}");

			batch.Clear();
			for (var j = 0; j < n_eval; j++)
				batch.Add(tokens[i + j], n_past++, LLamaSeqId.Zero, (i + j) == tokens.Count - 1);

			LlamaStep(inferWallClock, $"infer core: prefill chunk {chunkIdx} before Decode batch.TokenCount={batch.TokenCount}");
			if (LogPrefillBatchSummary)
			{
				GD.Print(
					$"GenerateResponse: prefill batch {chunkIdx + 1}/{totalPrefillBatches} — Decode starting ({n_eval} tokens in batch, wall_ms={inferWallClock.ElapsedMilliseconds})");
			}
			if (LogPrefillChunkDecodeSteps)
			{
				GD.Print(
					$"GenerateResponse: prefill chunk {chunkIdx} BEFORE Decode "
					+ $"(range=[{i},{i + n_eval}), n_past_start={nPastBeforeChunk}, batch_toks={batch.TokenCount}, wall_ms={inferWallClock.ElapsedMilliseconds})");
			}

			if (VerboseInferLogs())
				GD.Print(
					$"GenerateResponse: prefill Decode ENTER batch {chunkIdx + 1}/{totalPrefillBatches} (n_eval={n_eval}, n_past={nPastBeforeChunk}, wall_ms={inferWallClock.ElapsedMilliseconds}) — if nothing follows, llama.cpp Decode wedged here.");
			var chunkSw = System.Diagnostics.Stopwatch.StartNew();
			var preRc = context.Decode(batch);
			long chunkMs = chunkSw.ElapsedMilliseconds;
			if (VerboseInferLogs())
				GD.Print($"GenerateResponse: prefill Decode LEAVE batch {chunkIdx + 1}/{totalPrefillBatches} rc={preRc} chunk_ms={chunkMs} wall_ms={inferWallClock.ElapsedMilliseconds}");

			LlamaStep(inferWallClock, $"infer core: prefill chunk {chunkIdx} after Decode rc={preRc}");
			if (LogPrefillBatchSummary)
			{
				GD.Print(
					$"GenerateResponse: prefill batch {chunkIdx + 1}/{totalPrefillBatches} — Decode OK rc={preRc} chunk_ms={chunkMs} wall_ms={inferWallClock.ElapsedMilliseconds}");
			}
			if (LogPrefillChunkDecodeSteps)
			{
				GD.Print(
					$"GenerateResponse: prefill chunk {chunkIdx} AFTER Decode rc={preRc} "
					+ $"chunk_ms={chunkMs} wall_ms={inferWallClock.ElapsedMilliseconds}");
			}

			if (preRc != DecodeResult.Ok)
				throw new LLamaDecodeError(preRc);
			chunkIdx++;
		}

		LlamaStep(inferWallClock, $"infer core: prefill done ({chunkIdx} chunks), generation max_new={inferenceParams.MaxTokens}");
		long prefillMs = inferWallClock.ElapsedMilliseconds - prefillWallStartMs;
		if (VerboseInferLogs())
			GD.Print($"GenerateResponse: prefill COMPLETE — {chunkIdx} batches, ~{prefillMs} ms prefill wall — starting generation (max_new={inferenceParams.MaxTokens}).");

		var sb = new StringBuilder();
		long ttftMs = -1;
		int yieldChunks = 0;

		var maxTokens = inferenceParams.MaxTokens < 0 ? int.MaxValue : inferenceParams.MaxTokens;
		const int GenLogStride = 32;
		for (var i = 0; i < maxTokens && !cancellationToken.IsCancellationRequested; i++)
		{
			if (LogLlamaInferenceSteps && (i == 0 || (i % GenLogStride) == 0))
				LlamaStep(inferWallClock, $"infer core: gen i={i} before Sample");

			var id = inferenceParams.SamplingPipeline.Sample(context.NativeHandle, batch.TokenCount - 1);

			if (LogLlamaInferenceSteps && (i == 0 || (i % GenLogStride) == 0))
				LlamaStep(inferWallClock, $"infer core: gen i={i} after Sample id={id}");

			if (id.IsEndOfGeneration(weights.Vocab))
			{
				LlamaStep(inferWallClock, $"infer core: gen stopped — EOG at i={i}");
				break;
			}

			decoder.Add(id);
			var decoded = decoder.Read();
			if (yieldChunks == 0)
				ttftMs = inferWallClock.ElapsedMilliseconds;
			yieldChunks++;
			sb.Append(decoded);
			if (yieldChunks == 1 && VerboseInferLogs())
			{
				GD.Print(
					$"GenerateResponse: generation streaming — first token piece emitted (wall_ms={inferWallClock.ElapsedMilliseconds}, ttft_ms≈{ttftMs})");
			}

			if (antiprocessor.Add(decoded))
			{
				LlamaStep(inferWallClock, $"infer core: gen stopped — antiprompt at i={i}");
				break;
			}

			tokens.Clear();
			tokens.Add(id);

			if (n_past + tokens.Count >= context.ContextSize)
			{
				throw new InvalidOperationException(
					"LlamaService: KV cache would overflow. Raise ContextSize or shorten prompt / max_new_tokens.");
			}

			batch.Clear();
			batch.Add(id, n_past++, LLamaSeqId.Zero, true);

			if (LogLlamaInferenceSteps && (i == 0 || (i % GenLogStride) == 0))
				LlamaStep(inferWallClock, $"infer core: gen i={i} before step Decode");

			var stepRc = context.Decode(batch);

			if (LogLlamaInferenceSteps && (i == 0 || (i % GenLogStride) == 0))
				LlamaStep(inferWallClock, $"infer core: gen i={i} after step Decode rc={stepRc}");

			if (stepRc != DecodeResult.Ok)
				throw new LLamaDecodeError(stepRc);
		}

		LlamaStep(inferWallClock, $"infer core: exit yield_chunks={yieldChunks}");
		return (sb.ToString(), ttftMs, yieldChunks);
	}

	/// <summary>Mistral-7B-Instruct v0.2 format. We embed the entire game prompt as the instruction.</summary>
	private static string WrapMistralInstruct(string instruction, bool appendJsonObjectOutputFooter = true)
	{
		// Mistral expects <s>[INST] ... [/INST] and then assistant text.
		// CRITICAL: the three-pass merged LoRA was trained on very specific envelopes (see
		// training/data/tp{1,2,3}_*.jsonl). Match them byte-for-byte — any extra whitespace or
		// injected reminder text is train/inference drift that makes the model copy context or emit nothing.
		var body = instruction.Trim();

		// TP2 / TP3 (and any caller that supplies its own [INST]...[/INST] envelope):
		//   training row == "<s>" + body + "<completion>"   (no newline after <s>, completion right after [/INST])
		if (body.Contains("[INST]", StringComparison.Ordinal) && body.Contains("[/INST]", StringComparison.Ordinal))
			return "<s>" + body;

		if (!appendJsonObjectOutputFooter)
		{
			// TP1 (three-pass pass 1):
			//   training row == "<s>[INST] " + prompt + " [/INST]" + "Generated dialogue: <line></s>"
			// The prompt already ends with the "Generated dialogue: " priming line, so add NO reminder.
			return "<s>[INST] " + body + " [/INST]";
		}

		// Legacy single-pass JSON path (not used by the three-pass merged model).
		return "<s>[INST]\n"
			+ instruction
			+ "\n\nReturn ONLY the JSON object (no preface, no labels, no quotes around the whole thing). Start with '{'.\n"
			+ "[/INST]\n";
	}

	/// <summary>Win32 short path for native DLLs; returns original path if conversion fails.</summary>
	private static string ConvertToShortPathIfPossible(string fullPath)
	{
		if (string.IsNullOrEmpty(fullPath) || !File.Exists(fullPath))
			return fullPath;
		try
		{
			var shortPath = new StringBuilder(260);
			int result = NativeMethods.GetShortPathName(fullPath, shortPath, shortPath.Capacity);
			if (result > 0 && result < shortPath.Capacity)
			{
				string shortPathStr = shortPath.ToString();
				if (!string.IsNullOrEmpty(shortPathStr) && File.Exists(shortPathStr))
					return shortPathStr;
			}
		}
		catch (Exception ex)
		{
			GD.PushWarning($"ConvertToShortPathIfPossible: {ex.Message}");
		}
		return fullPath;
	}
}
