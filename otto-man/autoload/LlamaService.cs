using Godot;
using System;
using System.Text; // Required for Encoding, StringBuilder
using System.Threading.Tasks; // Required for async operations
using System.IO; // Add this for Path operations
using System.Collections.Generic; // Added for List

// <<< Add LLamaSharp usings >>>
using LLama;
using LLama.Common;
using LLama.Grammars;
using LLama.Native;
using LLama.Sampling; // <<< Add this >>>
using LLama.Extensions; // <<< Add this for potential extension methods >>>
// <<< End LLamaSharp usings >>>

public partial class LlamaService : Node, IDisposable
{
	// Signal emitted when generation is complete
	[Signal]
	public delegate void GenerationCompleteEventHandler(string result);

	// --- P/Invoke Declarations Removed --- 

	// --- Struct/Enum Definitions Removed ---

	// --- Class Members ---
	// <<< Native pointers removed, LLamaSharp objects will replace them >>>
	private bool _isInitialized = false;
	private bool _isDisposed = false;
	// <<< LLamaSharp model/context objects will be added here >>>
	private LLamaWeights _modelWeights;
	private LLamaContext _modelContext;
	private ModelParams _parameters;

	// --- Godot Lifecycle --- 
	public override void _Ready()
	{
		base._Ready();
		GD.Print("LlamaService Autoload _Ready.");
		
		// Initialize the model
		if (!Initialize("mistral-7b-instruct-v0.2.Q4_K_M.gguf"))
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

		// <<< LLamaSharp Initialization Logic Goes Here >>>
		try
		{
			// 1. Construct Model Path (Same as before)
			string modelLoadPath = "";
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
				modelLoadPath = Path.Combine(exeDir, modelFilename);
				GD.Print($"Exported Mode: Model path: {modelLoadPath}");
			}
			if (!File.Exists(modelLoadPath)) {
				throw new Exception($"Model file not found at: {modelLoadPath}");
			}

			// 2. Define Model Parameters
			_parameters = new ModelParams(modelLoadPath)
			{
				ContextSize = 4096, // Match original context size
				GpuLayerCount = 99, // Use GPU (LLamaSharp handles backend selection)
				UseMemoryLock = false, // Corresponds to use_mlock
				UseMemorymap = false // Corresponds to use_mmap
				// Add other parameters here if needed (e.g., Seed, Threads)
			};
			GD.Print($"Loading model with LLamaSharp: {modelLoadPath}, GpuLayerCount={_parameters.GpuLayerCount}");

			// 3. Load Model Weights
			_modelWeights = LLamaWeights.LoadFromFile(_parameters);
			GD.Print("LLamaSharp Model Weights Loaded.");

			// 4. Create Context
			_modelContext = _modelWeights.CreateContext(_parameters);
			GD.Print("LLamaSharp Model Context Created.");

			// 6. Mark as Initialized
			_isInitialized = true;
			GD.Print("LlamaService Initialized Successfully (using LLamaSharp).");
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
		// <<< LLamaSharp object disposal logic goes here >>>
		_modelContext?.Dispose(); // Dispose context if created
		_modelWeights?.Dispose(); // Dispose weights if loaded
		_modelContext = null;
		_modelWeights = null;
		_parameters = null;
		GD.Print("LLamaSharp resources cleaned.");
	}

	// --- Async Wrapper (Remains mostly the same) ---
	public void GenerateResponseAsync(string prompt, int maxNewTokens = 350)
	{
		if (!_isInitialized || _isDisposed)
		{
			GD.PrintErr("LlamaService not ready for GenerateResponseAsync.");
			EmitSignal(SignalName.GenerationComplete, "");
			return;
		}

		Task.Run(async () => {
			try { 
				string result = await GenerateResponse(prompt, maxNewTokens);
				// Print raw result for debugging
				GD.Print($"<<< RAW LLM RESULT >>>:\n{result}\n<<< END RAW LLM RESULT >>>"); 
				CallDeferred("emit_signal", SignalName.GenerationComplete, result ?? "");
			}
			catch (Exception ex) { GD.PrintErr($"Async gen error: {ex.Message}\n{ex.StackTrace}"); CallDeferred("emit_signal", SignalName.GenerationComplete, ""); }
		});
	}

	// --- Core Inference (To be re-implemented with LLamaSharp) ---
	private async Task<string> GenerateResponse(string prompt, int maxNewTokens = 350)
	{
		if (!_isInitialized || _isDisposed || _modelWeights == null || _parameters == null)
		{
			GD.PrintErr("GenerateResponse: LlamaService not initialized or objects missing.");
			return null;
		}
		
		// GD.PrintErr("LLamaSharp generation not yet implemented!");
		// return ""; // Placeholder
		try
		{
			var stopwatch = System.Diagnostics.Stopwatch.StartNew();
			GD.Print("GenerateResponse: Starting LLamaSharp inference...");

			// 1. Load grammar content
			string grammarContent = "";
			string baseDir = OS.HasFeature("editor")
				? ProjectSettings.GlobalizePath("res://").GetBaseDir()
				: Path.GetDirectoryName(OS.GetExecutablePath());
			GD.Print($"Attempting to load grammar from: {Path.Combine(baseDir, "grammars", "output.gbnf")}"); // Log path
			if (!string.IsNullOrEmpty(baseDir))
			{
				string grammarPath = Path.Combine(baseDir, "grammars", "output.gbnf");
				if (File.Exists(grammarPath))
				{
					GD.Print($"Grammar file exists. Last modified: {new System.IO.FileInfo(grammarPath).LastWriteTime}"); // Log modification time
					grammarContent = File.ReadAllText(grammarPath);

					// Attempt to sanitize the grammar content string
					GD.Print("Original grammarContent loaded (first 100 chars): " + grammarContent.Substring(0, Math.Min(100, grammarContent.Length)));
					grammarContent = grammarContent.Replace("\r\n", "\n"); // Normalize line endings
					// Specifically look for the problematic pattern if it persists due to weird characters
					// grammarContent = grammarContent.Replace("[ \t\n]*", "[ \t]*"); 
					// grammarContent = grammarContent.Replace("[ \t\r\n]*", "[ \t]*"); 
					GD.Print("Sanitized grammarContent for ws rule (first 100 chars): " + grammarContent.Substring(0, Math.Min(100, grammarContent.Length)));

					// GD.Print("Full grammarContent (first 200 chars): " + grammarContent.Substring(0, Math.Min(200, grammarContent.Length)));
					// int indexOfInfo = grammarContent.IndexOf("\"Info\""); // Look for "Info" with GBNF escapes
					// GD.Print("IndexOf '\"Info\"': " + indexOfInfo);

					// if (indexOfInfo != -1 && indexOfInfo + 10 <= grammarContent.Length) {
					// 	GD.Print("Byte representation of key part: " + BitConverter.ToString(Encoding.UTF8.GetBytes(grammarContent.Substring(indexOfInfo, 10))));
					// } else {
					// 	GD.Print("Could not find '\"Info\"' or not enough length for byte representation.");
					// }
					// GD.Print("Grammar content length: " + grammarContent.Length);
				}
				else { GD.PrintErr($"Grammar file not found at {grammarPath}"); }
			}
			else { GD.PrintErr("Failed to determine base directory for grammar."); }
			
			if(string.IsNullOrEmpty(grammarContent)){
				GD.PrintErr("Grammar content is empty, proceeding without grammar.");
			}

			// 2. Create an executor
			var executor = new StatelessExecutor(_modelWeights, _parameters);

			// 3. Define Inference Parameters (Assign Grammar Object Directly)
			SafeLLamaGrammarHandle grammarHandle = null; 
			if (!string.IsNullOrEmpty(grammarContent))
			{
				try 
				{
					// Parse the grammar string
					var parsedGrammar = LLama.Grammars.Grammar.Parse(grammarContent, "root"); 
					GD.Print("Grammar parsed successfully.");

					// Create an instance of the grammar - this directly returns the handle
					grammarHandle = parsedGrammar.CreateInstance();
					// GD.Print("Grammar instance created successfully."); // Redundant if CreateInstance IS the handle creation

					// Access the GrammarHandle property from the GrammarInstance object
					// grammarHandle = grammarInstance.GrammarHandle; // This line was incorrect

					if (grammarHandle == null || grammarHandle.IsInvalid)
					{
						GD.PrintErr("Parsed grammar but CreateInstance() returned an invalid or null handle.");
						grammarHandle = null; // Ensure it's null if invalid
					}
					else
					{
						GD.Print("Successfully obtained SafeLLamaGrammarHandle from parsedGrammar.CreateInstance().");
					}
				} 
				catch (Exception grammarEx)
				{
					GD.PrintErr($"Failed to parse grammar or create instance/handle: {grammarEx.Message}");
					GD.PrintErr(grammarEx.StackTrace);
					grammarHandle = null; 
				}
			}

			// --- TEMPORARY TEST: Force grammarHandle to null to test inference without grammar ---
			// GD.Print("TEMPORARY TEST: Forcing grammarHandle to null.");
			// grammarHandle = null; // REVERTED
			// --- END TEMPORARY TEST ---

			var inferenceParams = new InferenceParams()
			{
				Temperature = 0.8f, 
				AntiPrompts = new List<string> { "Player:" }, 
				MaxTokens = maxNewTokens,
				Grammar = grammarHandle // Assign the SafeLLamaGrammarHandle
			};

			// 4. Run Inference using await foreach
			StringBuilder resultBuilder = new StringBuilder();
			// CancellationToken.None is used here; consider if you need a proper token for cancellation.
			await foreach (var token_text in executor.InferAsync(prompt, inferenceParams, System.Threading.CancellationToken.None)) 
			{
				resultBuilder.Append(token_text);
			}
			string result = resultBuilder.ToString();

			stopwatch.Stop();
			GD.Print($"GenerateResponse: LLamaSharp inference completed in {stopwatch.ElapsedMilliseconds} ms.");
			return result;
		}
		catch (Exception e)
		{
			GD.PrintErr($"GenerateResponse Error (LLamaSharp): {e.Message}");
			GD.PrintErr(e.StackTrace);
			return null; // Indicate failure
		}
	}
}
