# Rogue Harem (otto-man) — agent instructions

Godot 4.3 **C#/Mono** project. Ottoman-themed roguelike-platformer + LLM-driven village sim.
Studio name: One Percent Games. Title "Rogue Harem" is LOCKED (trademark sanity check done).

> **Read this whole file before release-related work.** The blockers below are things the user
> has explicitly said he will not remember. Do not let them ship unnoticed.

---

## 🚨 HARD BLOCKERS — must be resolved before ANY public release

These do **not** block private test builds to a handful of people. They **do** block itch.io,
Steam, or any store page.

### 1. ~~FONT~~ — RESOLVED 2026-08-23
`assets/fonts/main_font.ttf` is now **Pixelify Sans**, SIL Open Font License 1.1,
`Copyright 2021 The Pixelify Sans Project Authors`, no Reserved Font Name (so the filename is
fine). Full OFL text is in `THIRD_PARTY_LICENSES.txt` §9, as the OFL requires.

The previous font was **"Fiery Turk", © 2008 Beycan Çetin, "All rights reserved"** — no
redistribution or commercial rights. It has been **deleted from the project entirely**. Do not
reintroduce it.

### 2. ~~AUDIO~~ — RESOLVED 2026-08-23
Sound effects come from two itch.io packs, both verified to permit commercial use with no
mandatory credit: "400 Sounds Pack" by CI, and "Free Fantasy 200 SFX Pack" by Tom Music. Both
forbid reselling the raw files, which this game does not do (audio is compiled into the `.pck`).
Credited in `THIRD_PARTY_LICENSES.txt` §8. Only open item: keep dated screenshots of both itch.io
pages as evidence of the terms at download time.

### 3. ~~ART~~ — RESOLVED 2026-08-23
Confirmed by the user: every sprite in `assets/` is hand-drawn original work by Goku. No
third-party art packs, no attribution owed.

---

**All three original blockers are now closed.** Keep this section and add to it if new
third-party assets are ever introduced — any new font, sound, sprite, or library needs its
license established before it ships.

---

## ⚠️ TEMPORARY FLAGS — must be `false` before any export

Both are dev-only conveniences. Grep them before exporting; never ship either as `true`.

| Flag | File | Ships as |
|---|---|---|
| `_PREVIEW_OFFER_IN_EDITOR` | `autoload/AiVillagers.gd` | `false` |
| `TEST_MODE` | `autoload/AiModelDownloader.gd` | `false` |

`TEST_MODE` swaps the 7.5 GB model download for a small test file. `_PREVIEW_OFFER_IN_EDITOR`
forces the AI offer screen in-editor and suppresses saving the player's choice.

---

## ⚠️ `export_presets.cfg` — THE EDITOR OVERWRITES IT

Two separate traps here.

**1. NEVER put `#` comment lines next to `include_filter`.** Godot's export-preset parser chokes
on them and writes the value back as `<null>` or `""`. This was diagnosed 2026-08-23: with a
comment block above it the value was wiped repeatedly; with the comments removed it persisted
immediately. The original project file also had a comment above `include_filter`, so **grammars
and the translation CSV may never have shipped in any earlier export** — which matches the
"exports never quite worked" history. Keep that line bare.

**2. The editor rewrites `export_presets.cfg` from its own in-memory state.** Only edit it with
Godot fully closed, then verify in the UI (Export → Resources tab) before exporting.

Correct values:

```
include_filter="*.png,*.gbnf"          # gbnf IN (read from pck), gguf OUT (native mmap)
dotnet/include_debug_symbols=false
application/product_name="Rogue Harem"
application/company_name="One Percent Games"
application/file_version="0.1.0.0"     # and product_version
application/copyright="© 2026 One Percent Games"
```

## 🔧 C# EXPORT: TargetFramework must stay net8.0

`otto-man.csproj` targets **net8.0**, not Godot's default net6.0. LLamaSharp 0.24 ships only
`lib/net8.0` and `lib/netstandard2.0`. A net6.0 project cannot consume net8.0 assets, so NuGet
silently falls back to the netstandard2.0 shim, whose native methods carry no implementation.
Result: `Could not load type 'LLama.Native.NativeApi' ... 'llama_backend_free' has no
implementation (no RVA)` — thrown at the first `ModelParams` construction, **after** `llama.dll`
had already loaded fine, which makes it look like a native problem when it is assembly selection.

Verify after any framework change: the `LLamaSharp.dll` in `.godot/mono/temp/bin/…` must be the
**~254 KB net8.0** build (md5 `45f643125aad078f9c18def59fbd6124`), never the **~237 KB
netstandard2.0** shim (md5 `d9491c34d4cb95793f589c5bb94fbde1`).

## 🔴 C# EXPORT: the CPU llama.dll silently overwrites the CUDA one

Backend.Cpu ships `llama.dll` in four variants (avx / avx2 / avx512 / **noavx**) and Backend.Cuda12
ships its own. Publish flattens every `runtimes/win-x64/native/**` into the publish root, so they
collide on filename and **last writer wins** — which in practice was the CPU **noavx** build, the
slowest variant in existence.

Symptom: everything looks fine. The model loads, inference runs, villagers eventually reply — but
`llama.cpp system info` lists only CPU features, there is no CUDA line, and the machine grinds.
Easy to mistake for a model or VRAM problem.

`FlattenLlamaSharpCuda12DllsToOutput` does NOT fix this: it runs `AfterTargets="Build"`, and publish
overwrites afterwards. The fix is `ForceCuda12NativesInPublish` (`AfterTargets="Publish"`), which
re-copies the cuda12 natives plus avx2's `ggml-cpu.dll` so CUDA wins last.

**Verify after every export** — `llama.dll` beside the exe must be the CUDA build:
```
cuda12 llama.dll md5 = e1b1e213685bb1275c341c597e317416
cpu noavx      md5 = 4e1371c42df6a1946c8b71eb7d642f96   ← wrong, means CPU-only
```
and the log's `llama.cpp system info` must show a CUDA device line.

## 🔧 C# EXPORT: duplicate publish files

`otto-man.csproj` sets `<ErrorOnDuplicatePublishOutputFiles>false</ErrorOnDuplicatePublishOutputFiles>`.
Required: LLamaSharp's Cpu and Cuda12 backends both publish a `ggml-base.dll` to the same relative
path, and Godot's export runs a *publish* (unlike `dotnet build`, which tolerates it). Without this
the export fails with "Failed to build project". Do not remove it, and do not drop either backend —
the CUDA stack links `ggml-cpu.dll`, which only Backend.Cpu provides.

Verified 2026-08-23: CUDA natives DO survive publish, flattened to the output root
(`ggml-cuda.dll` ~407 MB, `llama.dll`, `ggml*.dll`). Expected export size is therefore
**~900 MB – 1.1 GB**, not a few hundred MB.

`rcedit` (optional) stamps the exe metadata above; without it Godot warns and the file properties
stay blank. The exe itself works fine either way.

## 📦 MANUAL STEP AFTER EVERY EXPORT

Copy `THIRD_PARTY_LICENSES.txt` next to the exported `.exe`. It is deliberately **not** in the
`.pck` — inside the pck no player could read it, which defeats the purpose of a notices file.

Export output: `D:\otto_exp\otto-man.exe`. Uncheck "Export With Debug".

---

## Architecture facts that are easy to get wrong

**Never re-break these. Each cost real debugging time.**

- **Grammars are read via `Godot.FileAccess` from `res://grammars/`**, NOT `System.IO`. They live
  inside the `.pck`, which `System.IO` cannot see. The old exe-relative `File.ReadAllText` silently
  returned empty in every export, leaving the whole TP0-TP5 chain running unconstrained. Must be
  fully qualified as `Godot.FileAccess` — `System.IO.FileAccess` is also in scope in that file.
- **`export_presets.cfg` `include_filter` must keep `*.gbnf` and must NOT list `*.gguf`.** Grammars
  belong in the pck; the model must not (llama.cpp memory-maps it natively and cannot read a pck,
  so packing it added 7.5 GB of dead weight).
- **Model location**: editor → `res://models/`; export → `user://models/`
  (`%APPDATA%\Godot\app_userdata\otto-man\models\`). Never next to the exe — that folder is
  unwritable under Program Files / Steam, which broke on a second machine before.
- **GDScript cannot call `static` C# methods** through an autoload. `LlamaService` exposes instance
  wrappers (`HasModelFile`, `ModelFilePath`, `ModelDirectory`, `ModelFileName`) for this reason.
- **`AiVillagers` reaches `LlamaService` by node path** (`/root/LlamaService`), not as a global
  identifier, so it passes `--check-only` standalone instead of hiding real errors behind an
  autoload false-positive.
- **NPC "cannot speak" narration is never written to `Chat_log`.** That array feeds the TP0-TP5
  prompts; menu instructions in it would leak into a villager's remembered history.
- **🔴 Godot FLATTENS native DLLs in exports; the CUDA probe must handle both layouts.**
  In development NuGet puts llama.cpp's natives in `runtimes/win-x64/native/cuda12/` beside the
  managed assemblies. In an export Godot copies them flat into
  `data_<project>_windows_x86_64/`, and no `runtimes/` tree exists. The probe originally only
  looked for the `cuda12` folder, so in every export it resolved null, `LoadLibraryEx` was never
  called, the native library was never preloaded, and the first P/Invoke failed with
  `Could not load type 'LLama.Native.NativeApi' ... 'llama_backend_free' has no implementation
  (no RVA)`. That message reads like a managed-assembly problem but is really a native-load
  failure — do not go looking for trimming or assembly-version issues.
  `ResolveWindowsLlamaCuda12NativeDirOrNull()` now falls back to any candidate root containing
  `llama.dll` directly.

  **CUDA redistributables must ship with the game.** Confirmed 2026-08-23 by reading
  `ggml-cuda.dll`'s import table: it needs `nvcuda.dll` (ships with every NVIDIA driver, fine),
  plus **`cudart64_12.dll` and `cublas64_12.dll`**, which come only with the CUDA toolkit and are
  NOT on a normal gamer's machine. `cublas64_12.dll` in turn needs `cublasLt64_12.dll`.
  Sizes: cudart 0.5 MB, cublas 108 MB, **cublasLt 643 MB** — about **752 MB** total, bundled via
  the `CopyCudaRedistToOutput` target in `otto-man.csproj` from `native_redist/cuda12/`.
  CPU fallback is NOT acceptable: a 12B model on CPU is unusably slow.

  ### 📌 REVISIT LATER — backend strategy (decided 2026-08-23 to defer)
  Bundling 752 MB is the chosen short-term answer because it is non-disruptive, but it is not the
  best long-term one. Two alternatives were costed and deliberately postponed to avoid destabilising
  the first test export:
  - **Option B — switch to `LLamaSharp.Backend.Vulkan`.** Vulkan ships with the GPU driver on every
    vendor, so nothing needs bundling or installing. Would drop `ggml-cuda.dll` (407 MB) *and* the
    752 MB of CUDA redistributables — roughly **1.1 GB smaller** — and would work on **AMD and Intel**
    GPUs, which would let the "NVIDIA only" caveat come out of the AI Villagers offer screen.
    Cost: llama.cpp's Vulkan backend typically runs 70-90% of CUDA speed. Benchmark against the
    known-good baseline (~1-2s casual turn, ~6-8s significant turn on an RTX 3060) before adopting.
  - **Option C — ship both backends and select at runtime.** Best experience, largest build, most
    complexity.
- **🔴 Resource paths are CASE-SENSITIVE in an export, case-insensitive in the editor on Windows.**
  `village/buildings/well.tscn` was preloaded as `Well.tscn` by five different scripts. The editor
  resolved it fine; the exported `.pck` did not, and the failed `preload` killed the whole of
  `VillageScene.gd` — taking mentor interaction, build slots, and more with it, with only one line
  in the log. Fixed by renaming the file to `Well.tscn`. A full project scan afterwards found no
  other mismatches. **Re-scan after adding assets**: compare every `res://` reference in
  `.gd`/`.tscn`/`.tres` against the real filename with case-exact matching.
- **🔴 Nodes added INSIDE an instanced sub-scene are stripped from exports unless the scene
  declares `[editable path="Instance"]`.** This is the single biggest export trap in this project.
  A `.tscn` line like `[node name="X" parent="SomeInstance/Child" ...]` is only honoured in an
  export if that scene file ends with `[editable path="SomeInstance"]`. The editor honours it
  regardless, so everything looks fine while developing.

  Found 2026-08-23: **53 nodes across 4 scenes** were being silently dropped from every export —
  the whole village resource bar (`VillageStatusUI.tscn`, 39 nodes), the whole build menu
  (`BuildMenuUI.tscn`, 11), the mentor speech label, and the campfire's interaction collision
  shape. No scene in the project had the declaration. Added to
  `TutorialSpeechBar.tscn (Frame)`, `BuildMenuUI.tscn (BuildMenuPanel)`,
  `VillageStatusUI.tscn (TopBarPanel)`, `VillageScene.tscn (CampFire)`.

  **Re-run this scan after any scene work** — it lists nodes parented into a non-editable instance:
  find each `[node ... instance=ExtResource]` in a `.tscn`, then any `[node ... parent="ThatName/..."]`
  in the same file, and confirm the file has a matching `[editable path="ThatName"]`.

  Root cause of the whole class: these `.tscn` files were hand/tool-written rather than produced by
  Godot's editor. The same fingerprint shows in ~130 fake UIDs (`uid://parchment_frame_ui` instead
  of Godot's `uid://vjih7in2ygxx`). Treat any hand-edited scene as export-suspect.
- **`%UniqueName` breaks in exports for nodes inside an instanced sub-scene.** A node added into an
  instanced `.tscn` (its scene line carries `parent="Instanced/Child" index="N"`) does not reliably
  keep its unique-name registration once loaded from the binary `.scn`. It resolves in the editor
  and returns null in the export. This hid the entire mentor speech bar in the first export:
  `%SpeechRichText` returned null, and `TutorialSpeechBar._apply_visibility()` hides the panel when
  text is empty, so the window simply never appeared with one line in the log
  (`Node not found: "%SpeechRichText"`). `TutorialSpeechBar` now resolves via unique name → explicit
  path → recursive `find_child(name, true, false)` (the `owned = false` matters: nodes in an
  instanced sub-scene are not owned by the scene root). **If new UI goes missing only in exports,
  check this first.**
- **Translations load from the imported `.translation` resources, not the raw CSV.**
  `LocaleManager` originally did `FileAccess.open("res://localization/strings.csv")`. Godot treats
  `strings.csv` as an *import source* and ships the generated `strings.{tr,en}.translation` files
  instead — the raw `.csv` is not in the pck. That worked in the editor and silently failed in
  every export, showing raw keys (`ai.offer.title`) on screen instead of text. It now loads the
  `.translation` resources first and falls back to CSV parsing. Do not "simplify" it back.
- The 6-pass TP0-TP5 port into Godot is **DONE**. `docs/GODOT_NPC_LLM_ARCHITECTURE.md` still
  describes it as pending — that doc is stale on this point.

---

## Verification discipline (non-negotiable in this project)

Never trust reading code alone. After **every** edit:

```bash
# GDScript
"C:\Users\Aras\Desktop\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe" --headless --path "D:\OttoMan\otto-man\otto-man" --check-only --script "res://path/to/file.gd"
```

```bash
# C#
dotnet build "D:\OttoMan\otto-man\otto-man\otto-man.csproj" -v minimal --nologo
```

Full-project check (catches everything, autoloads loaded):
```bash
"C:\Users\Aras\Desktop\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe" --headless --path "D:\OttoMan\otto-man\otto-man" --quit
```

Known harmless noise in headless runs: `EnemyStats` resource errors, `.wav` import errors,
`InputManager` action warnings, RID leak warnings at exit. Ignore those; look for
`Compile Error` / `SCRIPT ERROR` / `Parse Error`.

`--check-only` on a file referencing an autoload by bare identifier reports
`Identifier not found: <Autoload>` — a false positive that **masks any real error after it**.
Prefer `get_node_or_null("/root/X")` in new code so files verify standalone.

**Never hand-edit `localization/strings.csv`.** Use a throwaway Godot script with
`FileAccess.store_csv_line()` (append-only, idempotent), run it headless, verify, then delete the
script. Quoting/escaping then comes from the exact parser `LocaleManager` reads with.

---

## Standing user preferences

- Communicate **briefly**. Short answers, no long explanations unless asked.
- **Stop and ask** whenever not 100% certain, even about minor things. The project is near demo
  completion; unannounced changes are unacceptable.
- Turkish + English must both be complete for every player-facing string. Translate properly, never
  machine-translation style. Turkish suffixes follow vowel harmony — never attach one to a dynamic
  `{name}`.
- No dash punctuation in player-facing popup copy.
- Do **not** run automated bulk debug-print removal. The user handles that himself.
- Never bias LLM outputs statistically; fix behavior through clearer prompt wording.

---

## Key documents

| File | What it holds |
|---|---|
| `LEGAL_CHECKLIST.txt` | AI disclosure, age rating, licenses, privacy, EULA, VAT. Pre-release blockers. |
| `THIRD_PARTY_LICENSES.txt` | Ships beside the exe. Godot/llama.cpp/LLamaSharp/.NET (MIT) + Mistral (Apache 2.0, full text). |
| `docs/AI_VILLAGERS_TEST_CHECKLIST.md` | Group A (editor) and Group B (export) test steps. |
| `docs/ROAD_TO_PUBLISHED_GAME.md` | Ordered publishing roadmap. |
| `docs/SHIP_PLAN.md` | Feature completion status. |
