# native_redist/ — NVIDIA CUDA redistributables

## What lives here

`cuda12/` holds three DLLs copied out of an NVIDIA CUDA 12.x toolkit:

| File | Size | Why |
|---|---|---|
| `cudart64_12.dll` | ~0.6 MB | CUDA runtime; `ggml-cuda.dll` imports it directly |
| `cublas64_12.dll` | ~98 MB | BLAS on GPU; `ggml-cuda.dll` imports it directly |
| `cublasLt64_12.dll` | ~637 MB | cuBLAS's own dependency — loaded by `cublas64_12.dll`, not by us |

**They are not in git.** `cublasLt64_12.dll` alone is ~6x GitHub's 100 MB per-file limit, so
`.gitignore` carries `otto-man/native_redist/**/*.dll` and this README is the only tracked file in
the folder. Every developer who takes an export puts their own copy here.

## Why they are needed

LLamaSharp's CUDA12 backend ships `ggml-cuda.dll`, which imports `cudart64_12.dll` and
`cublas64_12.dll`. Those two ship **only with the CUDA toolkit** — an NVIDIA *game driver* does not
include them. A player's machine therefore cannot load the CUDA backend, and llama.cpp falls back
to CPU. For a 12B model that is not "a bit slower", it is unusable.

So the export has to carry them next to the executable.

## The dangerous part

If this folder is empty, **the export still succeeds.** No error, no warning. And it works fine on
a developer machine, because the CUDA toolkit is on that machine's PATH — the DLLs get found
anyway. The failure only appears on a machine without the toolkit, i.e. every player.

That is why the verification below is not optional.

## How to get your copy

Requires the CUDA 12.x toolkit installed (`CUDA_12_KURULUM_REHBERI.md` in the repo root covers the
install). Then, from the repo root:

```powershell
$src = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9\bin"
New-Item -ItemType Directory -Force otto-man\native_redist\cuda12 | Out-Null
Copy-Item "$src\cudart64_12.dll","$src\cublas64_12.dll","$src\cublasLt64_12.dll" otto-man\native_redist\cuda12\
```

Adjust `v12.9` to whatever version is installed — any CUDA **12.x** works; 13.x does not (the DLLs
are named `*_13.dll` and `ggml-cuda.dll` will not bind them). If you have no toolkit, ask a
teammate to send you the folder instead.

## How they reach the export

`otto-man.csproj` picks the folder up as the `CudaRedist` item group and copies it twice:

- `CopyCudaRedistToOutput` (AfterTargets=`Build`) → for running from the Godot editor
- `CopyCudaRedistToPublish` (AfterTargets=`Publish`) → for the export, which runs publish, not build

The publish copy is the one that matters for shipping; the build copy does not carry over to it.

## Verifying an export (do both — this is the whole point)

1. **The three DLLs are beside the executable.** After exporting, look in
   `data_otto-man_windows_x86_64\`:

   ```powershell
   Get-ChildItem <export-dir>\data_otto-man_windows_x86_64\cu*64_12.dll |
     Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB)}}
   ```

   Three rows, ~637 / ~98 / ~1 MB. Fewer than three → the export is broken for players.

2. **The log says CUDA, not CPU.** Run the exported game and check the log for the
   `llama.cpp system info` line. It must contain a `CUDA :` entry. If it reads `CPU :` only, or you
   see `loaded llama.cpp is CPU-only`, the GPU path did not bind — the game is running on CPU and
   is unusably slow.

## Licensing

Redistribution of these files is permitted by the NVIDIA CUDA EULA; the attribution lives in
`otto-man/THIRD_PARTY_LICENSES.txt`.
