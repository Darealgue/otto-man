# LLamaSharp + CUDA 12 on Windows (Godot 4.3 Mono) — NPC merged GGUF session notes

This note captures what blocked **GPU** inference for months-hours of debugging and the **clear route** to a working stack (~2–3 s typical NPC turns on RTX 3060 class hardware with **merged** NPC weights).

Use it when onboarding a new agent or revisiting native load failures (`0x8007007E`, CPU-only `llama_print_system_info`).

---

## What “working with LoRA in ~2 seconds” actually means

- **NPC path uses a merged GGUF** (e.g. `mistral-7b-instruct-v0.2-NPC-merged.Q4_K_M.gguf`): base **Mistral-7B-Instruct v0.2** + **LoRA fused into one file** (`llama-export-lora` / merge workflow, then quantize).  
  See flags in `autoload/LlamaService.cs` (`NpcDialogueUseMergedNpcGguf`, `NpcMergedExclusiveDiskMode`, etc.).
- That is **not** the slow “second weights object + runtime GGUF LoRA adapter” path unless you explicitly enable it (generally avoided on CUDA for latency).
- **Speed** is dominated by **decode** (generated tokens). A healthy GPU stack shows **CUDA** in `llama_print_system_info` after load; wall times ~2–3 s for ~100+ tokens at NPC settings are consistent with GPU incremental decoding.

---

## Symptoms we hit (broken state)

- Log: `NativeLibrary.Load FAILED` on `...\runtimes\win-x64\native\cuda12\llama.dll` — **Win32 126** (`ERROR_MOD_NOT_FOUND`), often described as “missing module” (usually a **dependency**, not `llama.dll` itself).
- `llama_print_system_info` listed **CPU** features only — **no CUDA line** → runtime fell back to **CPU** `llama.dll`, so inference felt orders of magnitude slower than expected.
- User had **NVIDIA CUDA Toolkit** installed (`cudart64_12.dll` in e.g. `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.x\bin`) and **PATH** was adjusted in logs — **still failed** until the fixes below.

---

## Root causes (the real story)

### A) DLL search path for *dependent* DLLs (why PATH did not save `NativeLibrary.Load`)

- Recent **.NET** `NativeLibrary.Load` resolves natives via `LoadLibraryEx` with **`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS`**.
- With those flags, Windows **does not** use **`PATH`** to resolve **dependent** DLLs of `llama.dll` (e.g. **`cudart64_12.dll`**, **`cublas64_12.dll`** in the toolkit `bin`).
- So prepending CUDA `bin` to `PATH` was **necessary but insufficient** for that load mode.

**Fix (code):** Preload the CUDA stack using **`LoadLibraryEx(..., LOAD_WITH_ALTERED_SEARCH_PATH)`** so the classic **alternate search order** applies (DLL directory + **PATH** + system dirs). Do this **before** LLamaSharp’s first bind, so the **CUDA** `llama.dll` is the one that stays loaded. Implemented in `autoload/LlamaService.cs` (`TryPreloadWindowsCuda12LlamaDll` / `TryWindowsLoadLibraryAlteredSearchPath`).

### B) `ggml.dll` (CUDA) requires `ggml-cpu.dll` (not in the Cuda12 NuGet folder)

- `dumpbin /dependents` on `cuda12\ggml.dll` shows **`ggml-cpu.dll`**, **`ggml-cuda.dll`**, **`ggml-base.dll`**, etc.
- **`LLamaSharp.Backend.Cuda12`** ships **`cuda12\`** natives **without** `ggml-cpu.dll`.
- **`ggml-cpu.dll`** comes from **`LLamaSharp.Backend.Cpu`** under `runtimes/win-x64/native/avx` (or `avx2`, …).

**Fix (project):** Add **`PackageReference` `LLamaSharp.Backend.Cpu`** (same version as Cuda12, e.g. 0.24.0) and an **MSBuild** step after build to copy **`ggml-cpu.dll`** (e.g. from **`avx2`**) into **`runtimes\win-x64\native\cuda12\`** so it sits next to `ggml.dll`, then **flatten** `cuda12\*.dll` next to `otto-man.dll` as already documented for SciSharp/LLamaSharp layout. See `otto-man.csproj` target **`FlattenLlamaSharpCuda12DllsToOutput`**.

**Preload order** in `LlamaService.cs`: `ggml-base` → `ggml-cpu` → `ggml-cuda` → `ggml` → `llama` (all with altered search path), so failures are diagnosable per DLL.

### C) Windows / .NET native binding hygiene

- **`PlatformTarget=x64`**, **`Prefer32Bit=false`** for non-Android/non-iOS (see `otto-man.csproj`) — avoids wrong-bitness and flaky CUDA binding.
- **`SetDllDirectory`**: default **off** in our setup (can shrink search and hide toolkit `bin`). Opt-in via **`OTTO_LLAMA_USE_SETDLLDIR=1`** if ever needed.

---

## Clear verification checklist

1. After load, log contains **`CUDA : ARCHS = ...`** (or similar) inside **`llama_print_system_info`** — not CPU-only.
2. Preload log: **`LoadLibraryEx OK (LOAD_WITH_ALTERED_SEARCH_PATH)`** for `llama.dll` (not repeated `126`).
3. `runtimes\win-x64\native\cuda12\` contains **`ggml-cpu.dll`** after build (not only `ggml-cuda.dll`).
4. NPC inference uses **merged** path when configured — logs mention merged GGUF / single VRAM load; `npcRuntimeLora` false unless you opted into adapter GGUF.

**Diagnostics env (see `LlamaService.cs`):**  
`OTTO_LLAMA_VERBOSE=1`, `OTTO_LLAMA_SKIP_NATIVE_PRELOAD=1`, `OTTO_LLAMA_USE_SETDLLDIR=1`, `OTTO_LLAMA_SKIP_SETDLLDIR=1`, etc.

---

## Related project docs / code

| Area | Location |
|------|----------|
| Native preload + PATH + CUDA probe | `autoload/LlamaService.cs` |
| NPC prompt, significance, JSON merge | `autoload/NPCDialogueManager.gd` |
| Godot UI applies `Info.Name` to nameplate | `ui/npc_window.gd` → `NPCDialogueProcessed` → `Worker.Update_Villager_Name()` |
| Agent-oriented project overview | `grammars/dev_session_prompt.txt` |
| Dataset / training conventions | `training/DATASET_RULES_AND_FEEDBACK.md`, `training/WHERE_WE_LEFT_OFF.md` |
| Example SFT lines (titles, significance) | `training/data/npc_sft.v2.manual.jsonl` (and backups) |

---

## LoRA quality vs base model (separate from CUDA)

- **Merged** weights can look **weaker** on significance / JSON discipline than base if: **small SFT set**, **train prompt ≠ runtime prompt** (`NPCDialogueManager` vs short `Rules (short):` in JSONL), or merge/quantize effects.
- **Mitigation plan:** freeze a **cleaner production prompt**, mirror it in **`training/data/npc_sft.v2.manual.jsonl`**, retrain LoRA, re-merge, ship new merged GGUF — plus a small **regression eval** copied verbatim from the game prompt.

---

## Next session (planned)

1. **Shorten / clean** the runtime NPC prompt in `NPCDialogueManager.gd` (clarity + alignment; latency is already acceptable — goal is **behavior** and **training match**).
2. **Update training JSONL** so prompts match that template.
3. **Train new LoRA** → **merge** → **quantize** → drop in **`res://models/`** as the new merged NPC GGUF.

### Safety nets (prompt + weights)

- **Prompt rollback:** canonical snapshot of `_construct_full_prompt` lives in **`grammars/prompts/NPC_DIALOGUE_PROMPT_CANONICAL_BACKUP.txt`**; see **`grammars/prompts/README.txt`** for restore steps and dated-copy naming.
- **Weights:** never overwrite the last known-good **merged GGUF** or **LoRA** in place — copy with a dated suffix (e.g. `…_PRE_REFACTOR_YYYY-MM-DD…`) before testing a new build.

---

*Last updated: session documenting Windows CUDA12 native load fixes + merged NPC inference context.*
