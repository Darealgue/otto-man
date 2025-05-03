using Godot;
using System;
using System.Runtime.InteropServices; // Required for P/Invoke
using System.Text; // Required for Encoding, StringBuilder
using System.Threading.Tasks; // Required for async operations
using System.IO; // Add this for Path operations
using System.ComponentModel; // For Win32Exception
using System.Linq;
using System.Runtime.CompilerServices; // For MethodImpl

public partial class LlamaService : Node, IDisposable
{
	// Signal emitted when generation is complete
	[Signal]
	public delegate void GenerationCompleteEventHandler(string result);

	// --- Removed Logging Callback Setup ---
	/*
	private delegate void ggml_log_callback(int level, byte[] text, IntPtr user_data);
	private static ggml_log_callback _logCallbackInstance;
	private static void LlamaLogCallback(int level, byte[] text, IntPtr user_data)
	{
		try 
		{
			if (text == null) return;
			string message = System.Text.Encoding.UTF8.GetString(text).Trim();
			if (!string.IsNullOrEmpty(message))
			{
				GD.Print($"[llama.cpp log]: {message}");
			}
		}
		catch(Exception ex)
		{
			GD.PrintErr($"[LlamaLogCallback Error]: {ex.Message}");
		}
	}
	*/
	// --- End Removed Logging Callback Setup ---

	// --- P/Invoke Declarations (Full version) ---
	private const string LlamaLib = "llama";
	private const string KernelLib = "kernel32";

	[DllImport(KernelLib, SetLastError = true, CharSet = CharSet.Unicode)] // Use Unicode version
	private static extern IntPtr LoadLibrary(string lpFileName);

	// Add P/Invoke for SetDllDirectory // <<< RE-ADD
	[DllImport(KernelLib, SetLastError = true, CharSet = CharSet.Unicode)]
	[return: MarshalAs(UnmanagedType.Bool)]
	private static extern bool SetDllDirectory(string lpPathName); // null to restore default

	[StructLayout(LayoutKind.Sequential)]
	private struct llama_model_params { /* ... fields ... */
		public IntPtr devices; public IntPtr tensor_buft_overrides; public int n_gpu_layers;
		public LlamaSplitMode split_mode; public int main_gpu; public IntPtr tensor_split;
		public IntPtr progress_callback; public IntPtr progress_callback_user_data;
		public IntPtr kv_overrides; [MarshalAs(UnmanagedType.I1)] public bool vocab_only;
		[MarshalAs(UnmanagedType.I1)] public bool use_mmap; [MarshalAs(UnmanagedType.I1)] public bool use_mlock;
		[MarshalAs(UnmanagedType.I1)] public bool check_tensors;
	}
	private enum LlamaSplitMode { LLAMA_SPLIT_MODE_NONE=0, LLAMA_SPLIT_MODE_LAYER=1, LLAMA_SPLIT_MODE_ROW=2 }

	// Updated llama_context_params to match llama.h more closely
	[StructLayout(LayoutKind.Sequential)]
	public struct llama_context_params {
		public uint n_ctx;             // text context, 0 = from model
		public uint n_batch;           // logical maximum batch size
		public uint n_ubatch;          // physical maximum batch size
		public uint n_seq_max;         // max number of sequences
		public int  n_threads;         // number of threads for generation
		public int  n_threads_batch;   // number of threads for batch processing

		public int rope_scaling_type; // Use int for enum, map values if needed
		public int pooling_type;      // Use int for enum
		public int attention_type;    // Use int for enum

		public float rope_freq_base;
		public float rope_freq_scale;
		public float yarn_ext_factor;
		public float yarn_attn_factor;
		public float yarn_beta_fast;
		public float yarn_beta_slow;
		public uint  yarn_orig_ctx;
		public float defrag_thold;

		public IntPtr cb_eval; // ggml_backend_sched_eval_callback - map to delegate if used
		public IntPtr cb_eval_user_data;

		public int type_k; // Use int for ggml_type enum
		public int type_v; // Use int for ggml_type enum

		// Booleans - Ensure correct marshalling
		[MarshalAs(UnmanagedType.I1)] public bool logits_all; 
		[MarshalAs(UnmanagedType.I1)] public bool embeddings;
		[MarshalAs(UnmanagedType.I1)] public bool offload_kqv;
		[MarshalAs(UnmanagedType.I1)] public bool flash_attn;
		[MarshalAs(UnmanagedType.I1)] public bool no_perf;

		public IntPtr abort_callback; // ggml_abort_callback - map to delegate if used
		public IntPtr abort_callback_data;

		// --- Fields from older C# version that seem removed from latest llama.h ---
		// public uint seed; // Removed? Replaced by separate seed functions?
		// public int n_gpu_layers; // Now in model_params
		// public int main_gpu; // Now in model_params
	}

	[StructLayout(LayoutKind.Sequential)] public struct llama_token_data { public int id; public float logit; public float p; }
	[StructLayout(LayoutKind.Sequential)] public struct llama_token_data_array { public IntPtr data; public ulong size; public bool sorted; }

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern void llama_backend_init(bool numa = false);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern void llama_backend_free();
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern llama_model_params llama_model_default_params();
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern IntPtr llama_load_model_from_file(byte[] path_model, llama_model_params mparams);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern void llama_free_model(IntPtr model);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern llama_context_params llama_context_default_params();
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern IntPtr llama_new_context_with_model(IntPtr model, llama_context_params cparams);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern void llama_free(IntPtr ctx);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern int llama_n_ctx(IntPtr context);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern IntPtr llama_model_get_vocab(IntPtr model);
	[DllImport(LlamaLib, CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)] private static extern int llama_tokenize(
		IntPtr vocab, 
		byte[] text, 
		int text_len, 
		int[] tokens, 
		int n_max_tokens, 
		bool add_special, // Add BOS/EOS tokens
		bool parse_special // Parse special tokens
	);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern int llama_decode(IntPtr ctx, llama_batch batch);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern IntPtr llama_get_logits(IntPtr ctx);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern IntPtr llama_get_logits_ith(IntPtr ctx, int i);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern int llama_token_to_piece(
		IntPtr vocab, 
		int token, 
		byte[] buf, 
		int length, 
		int lstrip, 
		[MarshalAs(UnmanagedType.I1)] bool special);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern int llama_token_eos(IntPtr vocab);
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)] private static extern int llama_vocab_n_tokens(IntPtr vocab);

	// --- Removed Old Grammar P/Invokes ---

	// --- Standard greedy sampling - DEPRECATED / REMOVED in newer llama.cpp ---
	// [DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	// private static extern int llama_sample_token_greedy(
	// 	IntPtr ctx,
	// 	ref llama_token_data_array candidates
	// );

	// --- General sampling function (standalone) - DEPRECATED / REMOVED in newer llama.cpp ---
	// [DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	// private static extern int llama_sample_token(
	// 	IntPtr ctx,
	// 	ref llama_token_data_array candidates
	// );

	// --- New Sampler Chain P/Invokes ---
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern IntPtr llama_sampler_chain_init(
		IntPtr /* struct llama_sampler_chain_params* */ params_ptr // Passing IntPtr.Zero for default params
	);

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern void llama_sampler_chain_add(
		IntPtr /* struct llama_sampler* */ chain,
		IntPtr /* struct llama_sampler* */ sampler
	);

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern void llama_sampler_chain_free(
		IntPtr /* struct llama_sampler* */ chain
	);

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern IntPtr llama_sampler_init_greedy();

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern int llama_sampler_sample(
		IntPtr /* struct llama_sampler* */ sampler, // Can be a chain
		IntPtr /* struct llama_context* */ ctx,
		int idx // Index of logit to sample from (-1 for last)
	);

	// --- Grammar Sampler P/Invokes (Corrected based on latest API) ---
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern IntPtr llama_grammar_parse(
		IntPtr /* const char * */ grammar_str,
		UIntPtr /* size_t */ grammar_str_len,
		IntPtr /* const char * */ grammar_root
	);

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern void llama_grammar_free(
		IntPtr /* struct llama_grammar * */ grammar
	);
	
	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern IntPtr llama_sampler_init_grammar(
		IntPtr /* const struct llama_grammar * */ grammar // Correct: Takes parsed grammar object
	);

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern void llama_sampler_apply(IntPtr /* struct llama_sampler * */ sampler, ref llama_token_data_array candidates);

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern void llama_sampler_accept(IntPtr /* struct llama_sampler * */ sampler, int /* llama_token */ token);

	[DllImport(LlamaLib, CallingConvention = CallingConvention.Cdecl)]
	private static extern void llama_sampler_free(IntPtr /* struct llama_sampler * */ sampler);

	// --- Structs --- Required for llama_decode
	[StructLayout(LayoutKind.Sequential)]
	public struct llama_batch
	{
		public int n_tokens;
		public IntPtr token;    // int*
		public IntPtr embd;     // float* - unused for now
		public IntPtr pos;      // int*
		public IntPtr n_seq_id; // int* - unused for basic generation (set to null)
		public IntPtr seq_id;   // int** - unused for basic generation (set to null)
		public IntPtr logits;   // sbyte* (int8_t*)
	}
	// --- End Structs ---

	// --- Class Members ---
	private IntPtr _llamaModel = IntPtr.Zero;
	private IntPtr _llamaContext = IntPtr.Zero;
	private bool _isInitialized = false;
	private bool _isDisposed = false;
	private int _nCtx = 0;
	private int _vocabSize = 0;
	private int _eosTokenId = -1;
	private IntPtr _llamaGrammarSampler = IntPtr.Zero; // <<< Re-enable
	private IntPtr _llamaGreedySampler = IntPtr.Zero; // <<< Re-enable
	// private IntPtr _samplerChain = IntPtr.Zero; // <<< Keep commented out
	private IntPtr _parsedGrammar = IntPtr.Zero; // <<< Re-enable

	// --- Godot Lifecycle --- 
	public override void _Ready()
	{
		base._Ready();
		GD.Print("LlamaService Autoload _Ready.");
	}

	// --- Initialization and Cleanup (Full Version) ---
	public bool Initialize(string modelFilename)
	{
		if (_isInitialized) return true;
		GD.Print($"LlamaService Initialize called with: {modelFilename}");
		// _tokensInKvCache = 0; // Removed

		// ---> Declare gpuLayers here for wider scope, set to 99 <---
		int gpuLayers = 99; 

		// ---> Removed call to llama_log_set
		/* 
		_logCallbackInstance = LlamaLogCallback; 
		llama_log_set(_logCallbackInstance, IntPtr.Zero);
		GD.Print("llama.cpp log callback set.");
		*/
		// <--- 

		string modelLoadPath = "";
		string libLoadPath = "";

		try
		{
			// --- Construct Paths (Model/Lib) ---
			if (OS.HasFeature("editor"))
			{
				string projectRoot = ProjectSettings.GlobalizePath("res://");
				if (string.IsNullOrEmpty(projectRoot)) { throw new Exception("Failed to globalize project path res://"); }
				modelLoadPath = Path.Combine(projectRoot, "models", modelFilename);
				libLoadPath = Path.Combine(projectRoot, "bin", LlamaLib + ".dll"); // <<< Point back to bin
				GD.Print($"Editor Mode: Model path: {modelLoadPath}");
				GD.Print($"Editor Mode: Library path: {libLoadPath}");
			}
			else
			{
				string exePath = OS.GetExecutablePath();
				string exeDir = Path.GetDirectoryName(exePath);
				if (string.IsNullOrEmpty(exeDir)) { throw new Exception("Failed to get executable directory!"); }
				modelLoadPath = Path.Combine(exeDir, modelFilename);
				libLoadPath = Path.Combine(exeDir, LlamaLib + ".dll");
				GD.Print($"Exported Mode: Model path: {modelLoadPath}");
				GD.Print($"Exported Mode: Library path: {libLoadPath}");
			}

			// --- Check File Existence (Model/Lib) ---
			if (!File.Exists(modelLoadPath)) {
				GD.PrintErr($"Model file not found at: {modelLoadPath}");
				return false;
			}
			if (!File.Exists(libLoadPath)) {
				GD.PrintErr($"Library file not found at: {libLoadPath}");
				return false;
			}

			// --- Explicitly Load Native Libraries --- // <<< REINSTATE SetDllDirectory & Explicit Load
			string binDirectory = Path.GetDirectoryName(libLoadPath);
			bool directorySet = false;
			try
			{
				GD.Print($"Attempting to add '{binDirectory}' to DLL search path...");
				directorySet = SetDllDirectory(binDirectory);
				if (!directorySet)
				{
					int errorCode = Marshal.GetLastWin32Error();
					GD.PrintErr($"SetDllDirectory failed for '{binDirectory}'. Win32 Error: {errorCode} - {new Win32Exception(errorCode).Message}. Proceeding anyway, but dependency loading might fail.");
				}
				else
				{
					GD.Print("Successfully added bin directory to DLL search path.");
				}

				// ---> Pre-load dependencies sequentially <--- 
				string[] dependencyDlls = { "ggml-base.dll", "ggml-cpu.dll", "ggml.dll" }; // Order might matter
				foreach (string dllName in dependencyDlls)
				{
					string dllPath = Path.Combine(binDirectory, dllName);
					GD.Print($"Pre-loading dependency: {dllPath}");
					IntPtr dllHandle = LoadLibrary(dllPath);
					if (dllHandle == IntPtr.Zero)
					{
						int errorCode = Marshal.GetLastWin32Error();
						string errorMessage = new Win32Exception(errorCode).Message;
						throw new DllNotFoundException($"LoadLibrary failed for dependency '{dllPath}' after setting DLL directory. Win32 Error: {errorCode} - {errorMessage}. Check VC++ Redistributable and file presence."); 
					}
					GD.Print($"Successfully pre-loaded {Path.GetFileName(dllPath)} (Handle: {dllHandle}).");
				}
				// --- End pre-load ---

				// Now load the main llama.dll
				GD.Print($"Attempting explicit LoadLibrary for: {libLoadPath}"); // libLoadPath points to llama.dll
				IntPtr libHandle = LoadLibrary(libLoadPath);
				if (libHandle == IntPtr.Zero)
				{
					int errorCode = Marshal.GetLastWin32Error();
					string errorMessage = new Win32Exception(errorCode).Message;
					throw new DllNotFoundException($"Explicit LoadLibrary failed for '{libLoadPath}' after successfully pre-loading dependencies and setting DLL directory. Win32 Error: {errorCode} - {errorMessage}. Ensure the DLL and its dependencies (CUDA runtime, VC++ Redist) are present in '{binDirectory}'."); // Reverted error message, noted ggml success
				}
				GD.Print($"Explicit LoadLibrary succeeded for {Path.GetFileName(libLoadPath)} (Handle: {libHandle}). Proceeding...");
				// NOTE: We don't need to FreeLibrary here

				// ---> Call backend_init AFTER LoadLibrary succeeds <---
				GD.Print("Attempting initial call to llama_backend_init(false)...");
				llama_backend_init(false);
				GD.Print("llama_backend_init(false) called successfully.");
				// --- End initial call test ---

				// ---> Set n_gpu_layers back to 99 // <<< Already handled above with gpuLayers variable
				// int gpuLayers = 99; 
				// GD.Print($"Setting n_gpu_layers = {gpuLayers}"); 

			}
			finally
			{
				// Restore default DLL search path
				if (directorySet)
				{
					SetDllDirectory(null);
					GD.Print("Restored default DLL search path.");
				}
			}
			// Relying on implicit P/Invoke loading. Ensure DLLs are in bin/ or PATH. // <<< Remove inaccurate comment


			// --- Diagnostic Check --- 
			// Moved llama_backend_init call earlier

			// --- Continue with Llama Init (Model & Context) ---
			byte[] modelPathBytes = Encoding.UTF8.GetBytes(modelLoadPath);
			GD.Print("Initializing Llama backend..."); // Now the first P/Invoke call
			llama_backend_init(false); 
			GD.Print("Setting up model params...");
			llama_model_params modelParams = llama_model_default_params();
			modelParams.use_mmap = true;
			modelParams.use_mlock = false; 
			modelParams.n_gpu_layers = gpuLayers; // <<< USE VARIABLE SET EARLIER
			GD.Print($"Loading model: {modelLoadPath}...");
			_llamaModel = llama_load_model_from_file(modelPathBytes, modelParams);
			if (_llamaModel == IntPtr.Zero) { throw new Exception("Failed to load model."); }
			GD.Print("Model loaded.");

			GD.Print("Setting up context params...");
			llama_context_params contextParams = llama_context_default_params();
			contextParams.n_ctx = 4096;
			GD.Print("Creating context...");
			_llamaContext = llama_new_context_with_model(_llamaModel, contextParams);
			if (_llamaContext == IntPtr.Zero) { throw new Exception("Failed to create context."); }
			GD.Print("Context created.");
			
			// --- Get Vocab Pointer --- 
			IntPtr vocabPtr = llama_model_get_vocab(_llamaModel);
			if (vocabPtr == IntPtr.Zero) {
				throw new Exception("llama_model_get_vocab returned a null pointer.");
			}
			GD.Print($"Got vocab pointer: {vocabPtr}");

			// --- Initialize Samplers and Chain (Restructured) ---
			// === UNCOMMENT GRAMMAR PARSING ===
			/* // <<< START COMMENTING OUT GRAMMAR BLOCK
			GCHandle rootNameHandle = default;
			GCHandle grammarContentHandle = default; // Moved declaration out
			try 
			{
				// === Declare variables needed for grammar parsing in this scope ===
				string grammarFilePath;
				string grammarContent;
				IntPtr rulesPtr = IntPtr.Zero;
				UIntPtr grammarLength = UIntPtr.Zero;
				IntPtr rootNamePtr = IntPtr.Zero;
				byte[] grammarBytes; // Temporary variable for bytes
				byte[] rootNameBytes; // Temporary variable for bytes

				// === Step 1: Prepare Grammar Data (Inner Try for File IO) ===
				GD.Print("Preparing grammar data...");
				try {
					// ... baseDir calculation ...
					// Corrected: Define baseDir within this block if needed
					string baseDir = OS.HasFeature("editor")
						? ProjectSettings.GlobalizePath("res://")
						: Path.GetDirectoryName(OS.GetExecutablePath());
					if (string.IsNullOrEmpty(baseDir)) { throw new Exception("Failed to determine base directory for grammar."); }

					string grammarRelativePath = Path.Combine("grammars", "output.gbnf");
					grammarFilePath = Path.Combine(baseDir, grammarRelativePath); // NO string HERE
					if (!File.Exists(grammarFilePath)) { throw new Exception($"Grammar file not found: {grammarFilePath}"); }
					grammarContent = File.ReadAllText(grammarFilePath); // NO string HERE
					grammarBytes = Encoding.UTF8.GetBytes(grammarContent);
					grammarContentHandle = GCHandle.Alloc(grammarBytes, GCHandleType.Pinned);
					rulesPtr = grammarContentHandle.AddrOfPinnedObject(); // NO IntPtr HERE
					grammarLength = (UIntPtr)grammarBytes.Length; // NO UIntPtr HERE (already declared outside)
					string rootRuleName = "root";
					rootNameBytes = Encoding.UTF8.GetBytes(rootRuleName + "\0"); // Add null terminator if required by llama_grammar_parse
					rootNameHandle = GCHandle.Alloc(rootNameBytes, GCHandleType.Pinned);
					rootNamePtr = rootNameHandle.AddrOfPinnedObject(); // NO IntPtr HERE
				} catch (Exception grammarEx) {
				   GD.PrintErr($"Error reading/pinning grammar file (during init): {grammarEx.Message}");
				   if (rootNameHandle.IsAllocated) rootNameHandle.Free(); // Cleanup handles on error
				   if (grammarContentHandle.IsAllocated) grammarContentHandle.Free();
				   throw; // Re-throw
				}
				// Inner try ends, variables rulesPtr, grammarLength, rootNamePtr are now set.

				// === Step 2: Parse Grammar (using variables from outer scope) ===
				GD.Print("Attempting llama_grammar_parse..."); 
				_parsedGrammar = llama_grammar_parse(rulesPtr, grammarLength, rootNamePtr);
				GD.Print($"llama_grammar_parse result: {_parsedGrammar}");
				if (_parsedGrammar == IntPtr.Zero) { throw new Exception("Failed to parse grammar (llama_grammar_parse returned null)."); }
				GD.Print("Grammar parsed successfully.");

				// === Step 3: Initialize Grammar Sampler ===
				GD.Print("Attempting llama_sampler_init_grammar...");
				_llamaGrammarSampler = llama_sampler_init_grammar(_parsedGrammar);
				GD.Print($"llama_sampler_init_grammar result: {_llamaGrammarSampler}");
				if (_llamaGrammarSampler == IntPtr.Zero) { throw new Exception("Failed to initialize grammar sampler from parsed grammar."); }
				GD.Print("Grammar sampler initialized successfully.");

				// === Step 4: Initialize Greedy Sampler === // Need this handle too
				GD.Print("Attempting llama_sampler_init_greedy...");
				_llamaGreedySampler = llama_sampler_init_greedy();
				GD.Print($"llama_sampler_init_greedy result: {_llamaGreedySampler}");
				if (_llamaGreedySampler == IntPtr.Zero) { throw new Exception("Failed to initialize greedy sampler."); }
				GD.Print("Greedy sampler initialized successfully.");

				// === Step 5: Initialize Sampler Chain ===
				GD.Print("Attempting llama_sampler_chain_init...");
				_samplerChain = llama_sampler_chain_init(IntPtr.Zero);
				GD.Print($"llama_sampler_chain_init result: {_samplerChain}");
				if (_samplerChain == IntPtr.Zero) { throw new Exception("Failed to initialize sampler chain."); }
				GD.Print("Sampler chain initialized successfully.");

				// === Step 6: Add samplers to chain (ORDER MATTERS!) ===
				GD.Print("Attempting llama_sampler_chain_add (Grammar Sampler)...");
				llama_sampler_chain_add(_samplerChain, _llamaGrammarSampler); // Apply grammar first
				GD.Print("Attempting llama_sampler_chain_add (Greedy Sampler)...");
				llama_sampler_chain_add(_samplerChain, _llamaGreedySampler);  // Add greedy sampler back to the chain
				GD.Print("Samplers added to chain.");
			}
			finally // Outer finally to ensure handles are freed even if sampler init fails
			{
				// Free grammar prep handles
				if (rootNameHandle.IsAllocated) rootNameHandle.Free();
				if (grammarContentHandle.IsAllocated) grammarContentHandle.Free(); 
				GD.Print("Grammar prep handles freed (if allocated).");
			}
			*/ // <<< END COMMENTING OUT GRAMMAR BLOCK

			// === Initialize ONLY the Greedy Sampler for now === // <<< REMOVE THIS BLOCK (covered above)
			/*
			GD.Print("Initializing greedy sampler...");
			_llamaGreedySampler = llama_sampler_init_greedy();
			if (_llamaGreedySampler == IntPtr.Zero) { throw new Exception("Failed to initialize greedy sampler."); }
			GD.Print("Greedy sampler initialized successfully.");
			*/

			// --- End Sampler Initialization ---


			// Get EOS and Vocab Size (can happen after samplers)
			_eosTokenId = llama_token_eos(vocabPtr);

			// Vocab size: Need the specific function from llama.h (llama_vocab_n_tokens)
			_vocabSize = llama_vocab_n_tokens(vocabPtr);

			// Check raw values (including EOS this time)
			_nCtx = llama_n_ctx(_llamaContext);
			GD.Print($"Retrieved raw params: Ctx={_nCtx}, Vocab={_vocabSize}, EOS={_eosTokenId}");

			// Check validity
			if (_nCtx <= 0 || _vocabSize <= 0 || _eosTokenId < 0) // EOS token ID should not be negative
			{ 
				throw new Exception($"Failed to get valid context/vocab/eos parameters. Ctx={_nCtx}, Vocab={_vocabSize}, EOS={_eosTokenId}"); 
			}

			GD.Print($"Final Check - Retrieved params: Ctx={_nCtx}, Vocab={_vocabSize}, EOS={_eosTokenId}");

			_isInitialized = true;
			GD.Print("LlamaService Initialized Successfully.");
			return true;
		}
		catch (Exception e)
		{
			GD.PrintErr($"LlamaService Initialization failed: {e.Message}");
			GD.PrintErr(e.StackTrace);
			CleanupNativeResources(); // Attempt cleanup on failure
			_isInitialized = false;
			return false;
		}
	}

	// Helper to check initialization status
	public bool IsInitialized() => _isInitialized;

	// --- Dispose Pattern (Full Version) ---
	public new void Dispose() { Dispose(true); GC.SuppressFinalize(this); }
	protected override void Dispose(bool disposing)
	{
		if (_isDisposed) return;
		CleanupNativeResources();
		_isDisposed = true;
		_isInitialized = false;
		base.Dispose(disposing); // Call base class dispose
	}
	~LlamaService() { Dispose(false); } // Finalizer

	private void CleanupNativeResources()
	{
		GD.Print("Cleaning up native Llama resources...");
		// --- UNCOMMENT GRAMMAR CLEANUP --- //
		/* // <<< START COMMENTING OUT GRAMMAR CLEANUP
		// Free sampler chain FIRST (this *should* free contained samplers, but needs verification)
		// if (_samplerChain != IntPtr.Zero) { llama_sampler_chain_free(_samplerChain); _samplerChain = IntPtr.Zero; GD.Print("Sampler chain freed."); }
		
		// Free the parsed grammar object
		if (_parsedGrammar != IntPtr.Zero) { llama_grammar_free(_parsedGrammar); _parsedGrammar = IntPtr.Zero; GD.Print("Parsed grammar object freed."); }

		// We might not need to free these individually if chain handles it, but keep commented for safety
		// We DEFINITELY need to free the grammar sampler if it was created outside the chain context
		if (_llamaGrammarSampler != IntPtr.Zero) { llama_sampler_free(_llamaGrammarSampler); _llamaGrammarSampler = IntPtr.Zero; GD.Print("Grammar sampler freed."); }
		*/ // <<< END COMMENTING OUT GRAMMAR CLEANUP

		// --- Free Greedy Sampler (if initialized) --- // <<< Keep this
		if (_llamaGreedySampler != IntPtr.Zero)
		{
			 // Check llama.cpp API: Does llama_sampler_free work for greedy? Assuming yes.
			 llama_sampler_free(_llamaGreedySampler);
			 _llamaGreedySampler = IntPtr.Zero;
			 GD.Print("Greedy sampler freed.");
		}
		// We might not need to free these individually if chain handles it, but keep commented for safety
		// if (_llamaGrammarSampler != IntPtr.Zero) { llama_sampler_free(_llamaGrammarSampler); _llamaGrammarSampler = IntPtr.Zero; GD.Print("Grammar freed."); } 
		if (_llamaContext != IntPtr.Zero) { llama_free(_llamaContext); _llamaContext = IntPtr.Zero; GD.Print("Context freed."); }
		if (_llamaModel != IntPtr.Zero) { llama_free_model(_llamaModel); _llamaModel = IntPtr.Zero; GD.Print("Model freed."); }
		// Only free backend if we know it was initialized (could track separately)
		// For now, assume if model/context were valid, backend was too.
		if (_isInitialized) // Check the flag *before* setting it false in Dispose
		{
			 // llama_backend_free(); // Potentially risky if called multiple times - manage carefully
			 GD.Print("Backend free skipped (manage globally or on app exit).");
		}
	}

	// --- Async Wrapper (Full Version) ---
	public void GenerateResponseAsync(string prompt, int maxNewTokens = 128)
	{
		if (!_isInitialized || _isDisposed)
		{
			GD.PrintErr("LlamaService not ready for GenerateResponseAsync.");
			EmitSignal(SignalName.GenerationComplete, "");
			return;
		}

		// Restore Task.Run for background processing
		Task.Run(() => {
			try { 
				string result = GenerateResponse(prompt, maxNewTokens);
				// Important: Emit the signal back on the main thread for Godot
				CallDeferred("emit_signal", SignalName.GenerationComplete, result ?? "");
			}
			catch (Exception ex) { GD.PrintErr($"Async gen error: {ex.Message}\n{ex.StackTrace}"); CallDeferred("emit_signal", SignalName.GenerationComplete, ""); }
		});
	}

	// --- Core Inference (Full Version) ---
	private string GenerateResponse(string prompt, int maxNewTokens = 128)
	{
		if (!_isInitialized || _llamaContext == IntPtr.Zero)
		{
			GD.PrintErr("GenerateResponse: LlamaService not initialized.");
			return null;
		}
		if (_llamaGrammarSampler == IntPtr.Zero) // <<< Check if grammar sampler is ready
		{
			GD.PrintErr("GenerateResponse: Grammar Sampler not initialized.");
			return null;
		}
		if (_llamaGreedySampler == IntPtr.Zero) // <<< Check if greedy sampler is ready
		{
			GD.PrintErr("GenerateResponse: Greedy Sampler not initialized.");
			return null;
		}


		var stopwatch = System.Diagnostics.Stopwatch.StartNew();
		StringBuilder responseBuilder = new StringBuilder();
		GCHandle[] handlesToFree = new GCHandle[3]; // For token, pos, logits arrays in the loop

		try
		{
			// 1. Tokenize the prompt
			IntPtr vocabPtr = llama_model_get_vocab(_llamaModel);
			if (vocabPtr == IntPtr.Zero) throw new Exception("Failed to get vocab pointer.");

			byte[] promptBytes = System.Text.Encoding.UTF8.GetBytes(prompt);
			int[] promptTokens = new int[_nCtx]; // Max possible size
			int promptTokenCount = llama_tokenize(
				vocabPtr,
				promptBytes,
				promptBytes.Length,
				promptTokens,
				promptTokens.Length,
				true, // Add special BOS token if configured
				false // Don't parse special tokens in prompt
			);

			if (promptTokenCount < 0)
			{
				GD.PrintErr($"GenerateResponse: llama_tokenize failed! Code: {promptTokenCount}");
				return null;
			}

			int[] actualPromptTokens = new int[promptTokenCount];
			Array.Copy(promptTokens, actualPromptTokens, promptTokenCount);
			GD.Print($"GenerateResponse: Prompt tokenized into {promptTokenCount} tokens.");

			// --- Removed KV Cache Management Block ---
			/* // --- KV Cache Management ---
			// ... (All the if check, calculations, rm, update calls) ...
			*/ // --- End KV Cache Management ---

			// 2. Process the prompt using llama_decode
			llama_batch promptBatch = new llama_batch();
			int[] promptPos = Enumerable.Range(0, promptTokenCount).ToArray();
			sbyte[] promptLogits = new sbyte[promptTokenCount];
			promptLogits[promptTokenCount - 1] = 1; // Request logits only for the last token

			GCHandle promptTokensHandle = GCHandle.Alloc(actualPromptTokens, GCHandleType.Pinned);
			GCHandle promptPosHandle = GCHandle.Alloc(promptPos, GCHandleType.Pinned);
			GCHandle promptLogitsHandle = GCHandle.Alloc(promptLogits, GCHandleType.Pinned);

			try
			{
				promptBatch.n_tokens = promptTokenCount;
				promptBatch.token = promptTokensHandle.AddrOfPinnedObject();
				promptBatch.pos = promptPosHandle.AddrOfPinnedObject();
				promptBatch.n_seq_id = IntPtr.Zero; // Use default sequence 0 tracking
				promptBatch.seq_id = IntPtr.Zero;
				promptBatch.logits = promptLogitsHandle.AddrOfPinnedObject();
				promptBatch.embd = IntPtr.Zero;

				GD.Print($"GenerateResponse: Decoding prompt batch ({promptTokenCount} tokens)... Ctx: {_llamaContext}");
				int decodeResult = llama_decode(_llamaContext, promptBatch);
				if (decodeResult != 0)
				{
					throw new Exception($"llama_decode failed for prompt with code: {decodeResult}");
				}
				GD.Print($"GenerateResponse: Prompt decoded successfully."); // Simplified log
			}
			finally
			{
				if (promptTokensHandle.IsAllocated) promptTokensHandle.Free();
				if (promptPosHandle.IsAllocated) promptPosHandle.Free();
				if (promptLogitsHandle.IsAllocated) promptLogitsHandle.Free();
			}

			// 3. Generation Loop
			int currentPosition = promptTokenCount;
			int generatedTokenCount = 0;
			int nextToken = -1;

			while (currentPosition < _nCtx && generatedTokenCount < maxNewTokens)
			{
				// Sample the next token from the logits produced by the previous decode
				IntPtr logitsPtr = llama_get_logits_ith(_llamaContext, -1); // Get logits for the last token decoded
				if (logitsPtr == IntPtr.Zero) throw new Exception("llama_get_logits_ith returned null pointer.");

				// --- UNCOMMENT Candidate Population & Grammar Apply/Accept ---
				// We are skipping grammar for now, so no candidates array or apply call needed

				// --- Populate candidates array ---
				llama_token_data[] candidates = new llama_token_data[_vocabSize];
				float[] currentLogits = new float[_vocabSize];
				Marshal.Copy(logitsPtr, currentLogits, 0, _vocabSize); // Copy native logits to managed array
				for (int i = 0; i < _vocabSize; i++)
				{
					candidates[i] = new llama_token_data
					{
						id = i,
						logit = currentLogits[i],
						p = 0 // Not strictly needed for apply/greedy
					};
				}
				GCHandle candidatesHandle = GCHandle.Alloc(candidates, GCHandleType.Pinned);
				llama_token_data_array candidatesArray = new llama_token_data_array
				{
					data = candidatesHandle.AddrOfPinnedObject(),
					size = (ulong)_vocabSize,
					sorted = false // Greedy doesn't require sorted input, apply modifies in place
				};
				// --- End Populate ---

				// --- Apply Grammar Constraints ---
				llama_sampler_apply(_llamaGrammarSampler, ref candidatesArray);


				// --- Use ONLY the Greedy Sampler (on modified candidates) ---
				if (_llamaGreedySampler == IntPtr.Zero) throw new Exception("Greedy sampler not initialized!");
				// The `llama_sampler_sample` function for greedy directly uses the modified logits in the context
				// which were implicitly updated by the previous `llama_decode` call.
				// It does NOT directly use the `candidatesArray` for greedy.
				// `llama_sampler_apply` modified the candidatesArray, but greedy sampling itself
				// relies on the internal context state or getting logits again.
				// Let's stick to the official way: sample, then accept.
				// Llama.cpp examples often show: sample -> accept -> decode -> get_logits -> loop
				// It seems apply needs to happen *after* getting logits but *before* sampling.

				// Sample using the greedy sampler on the modified context state (implicitly using grammar-filtered logits)
				nextToken = llama_sampler_sample(_llamaGreedySampler, _llamaContext, -1);


				if (candidatesHandle.IsAllocated) candidatesHandle.Free(); // Free candidates handle after use

				// --- Accept the chosen token into the grammar state ---
				llama_sampler_accept(_llamaGrammarSampler, nextToken);


				// Check for EOS
				if (nextToken == _eosTokenId)
				{
					GD.Print("GenerateResponse: EOS token encountered.");
					break;
				}

				// Append the token to the response
				byte[] pieceBuffer = new byte[64]; // Buffer for token piece
				int pieceLength = llama_token_to_piece(
					vocabPtr,
					nextToken,
					pieceBuffer,
					pieceBuffer.Length,
					0,      // lstrip: Remove 0 leading spaces
					false); // special: Don't render special tokens

				if (pieceLength > 0)
				{
					responseBuilder.Append(System.Text.Encoding.UTF8.GetString(pieceBuffer, 0, pieceLength));
				}
				else if (pieceLength < 0)
				{
					GD.PrintErr($"GenerateResponse: llama_token_to_piece failed! Code: {pieceLength}");
					break;
				}

				generatedTokenCount++;

				// Prepare batch for the next token
				llama_batch tokenBatch = new llama_batch();
				int[] tokenArr = new int[] { nextToken };
				int[] posArr = new int[] { currentPosition }; // Use the current absolute position
				sbyte[] logitsArr = new sbyte[] { 1 };

				GCHandle tokenHandle = GCHandle.Alloc(tokenArr, GCHandleType.Pinned);
				GCHandle posHandle = GCHandle.Alloc(posArr, GCHandleType.Pinned);
				GCHandle logitsHandle = GCHandle.Alloc(logitsArr, GCHandleType.Pinned);
				handlesToFree[0] = tokenHandle; // Store handles to free outside loop in case of exception
				handlesToFree[1] = posHandle;
				handlesToFree[2] = logitsHandle;

				tokenBatch.n_tokens = 1;
				tokenBatch.token = tokenHandle.AddrOfPinnedObject();
				tokenBatch.pos = posHandle.AddrOfPinnedObject();
				tokenBatch.n_seq_id = IntPtr.Zero;
				tokenBatch.seq_id = IntPtr.Zero;
				tokenBatch.logits = logitsHandle.AddrOfPinnedObject();
				tokenBatch.embd = IntPtr.Zero;

				// Decode the single token batch
				int decodeTokenResult = llama_decode(_llamaContext, tokenBatch);

				// Free handles immediately after decode
				if (tokenHandle.IsAllocated) tokenHandle.Free();
				if (posHandle.IsAllocated) posHandle.Free();
				if (logitsHandle.IsAllocated) logitsHandle.Free();
				handlesToFree[0] = default; handlesToFree[1] = default; handlesToFree[2] = default;

				if (decodeTokenResult != 0)
				{
					throw new Exception($"llama_decode failed for token {nextToken} at pos {currentPosition} with code: {decodeTokenResult}");
				}
				currentPosition++; // Increment position for the next token
			}

			GD.Print($"GenerateResponse: Generated {generatedTokenCount} tokens.");
		}
		catch (Exception e)
		{
			GD.PrintErr($"GenerateResponse Error: {e.Message}");
			GD.PrintErr(e.StackTrace);
			// Ensure any handles allocated in the loop are freed on exception
			foreach (var handle in handlesToFree)
			{
				if (handle.IsAllocated) handle.Free();
			}
			return null; // Indicate failure
		}

		stopwatch.Stop();
		GD.Print($"GenerateResponse: Completed in {stopwatch.ElapsedMilliseconds} ms.");

		return responseBuilder.ToString();
	}
}
