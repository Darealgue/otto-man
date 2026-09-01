# Rogue Harem (otto-man) — agent instructions

Godot 4.3 **C#/Mono** project. Ottoman-themed roguelike-platformer + LLM-driven village sim.
Studio name: One Percent Games. Title "Rogue Harem" is LOCKED (trademark sanity check done).

> **Read this whole file before release-related work.** The blockers below are things the user
> has explicitly said he will not remember. Do not let them ship unnoticed.

---

## 🚨 HARD BLOCKERS — must be resolved before ANY public release

These do **not** block private test builds to a handful of people. They **do** block itch.io,
Steam, or any store page.

### 1. ~~FONT~~ — RESOLVED 2026-08-23, font swapped again 2026-08-26
`assets/fonts/main_font.ttf` is **Grenze** and `assets/fonts/title_font.ttf` is **Grenze
Gotisch**, both by Omnibus-Type, both SIL Open Font License 1.1, neither with a Reserved Font
Name (so renaming the files is fine — verified by reading both `OFL.txt` copyright lines). Full
notices and OFL text are in `THIRD_PARTY_LICENSES.txt` §10, as the OFL requires.

Both are **variable fonts** with a `wght` axis (100-900).

**🔴 `variation_opentype` silently ignores String keys.** `{"wght": 900}` parses fine, raises no
error, and changes nothing — the font renders at its default weight. Only the **integer OpenType
tag** works: `{2003265652: 900}` (that is `"wght"` as a big-endian 4-char tag, and it is what
Godot's own inspector serialises). Measured 2026-08-31 by summing glyph-atlas alpha through
`TextServer.font_get_texture_image()`: default 4159, String key `wght=900` 4159 (i.e. no effect),
integer key `wght=900` 7725.

This corrects an earlier note here claiming the weight axis does not change advance widths and
cannot be detected with `get_string_size()`. It does and it can — that conclusion came from the
String-key bug above. Measured widths of `"ONE PERCENT"` at 84px with integer keys:

| wght | 100 | 300 | 400 | 600 | 900 |
|---|---|---|---|---|---|
| px | 413 | 434 | 444 | 471 | 511 |

So a weight change **does** reflow text — budget for it in fixed-width UI.


These replaced **Pixelify Sans** (also OFL, legally fine) on 2026-08-26. It was dropped for
legibility: it is a pixel face whose glyphs need ≥20px to render evenly, while ~265 of this
project's font-size overrides sit at 10-14px, and its `5` reads as an `S`.

**🔴 The import settings are font-class-specific — do not carry them over blindly.** A pixel font
wants antialiasing off; a serif wants it on. Grenze needs
`antialiasing=1` (Gray), `hinting=2` (Normal), `subpixel_positioning=1` (Auto) in
`main_font.ttf.import`. With the pixel-font settings (all `0`) a serif is unreadable at small
sizes and it looks like the font is at fault.

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
**~1.4 GB** (re-verified 2026-09-02), not a few hundred MB. That figure now includes the ~735 MB of
NVIDIA CUDA redistributables copied in from `native_redist/cuda12/` — see `native_redist/README.md`.
Without them the export is ~700 MB and silently CPU-only on any machine without a CUDA toolkit,
i.e. every playtester's.

## 🔴 `rcedit` IS NOT OPTIONAL — without it the exe ships with the GODOT ICON

Godot 4.3 does **not** write Windows PE resources itself. `application/icon`,
`application/console_wrapper_icon` and every `application/*_name` / `*_version` /
`copyright` field in `export_presets.cfg` are applied by an external tool, `rcedit.exe`,
whose path lives in **Editor Settings → Export → Windows → Rcedit**
(`export/windows/rcedit` in `%APPDATA%\Godot\editor_settings-4.3.tres`).

If that setting is empty, the export still succeeds with only a warning in the log
("Could not start rcedit executable. Configure rcedit path in the Editor Settings") and the
resulting `.exe` keeps the **Godot robot icon** and `ProductName = Godot Engine`. This is
exactly what happened to the 2026-08-30 build. Verify after every export:

```powershell
(Get-Item "path\to\otto-man.exe").VersionInfo | Format-List ProductName,CompanyName,FileVersion
# must say "Rogue Harem" / "One Percent Games" / 0.1.0.0 — NOT "Godot Engine"
```

Windows caches exe icons aggressively; if the metadata is right but Explorer still shows the
old icon, refresh with `ie4uinit.exe -show`.


## 📦 MANUAL STEP AFTER EVERY EXPORT

Copy `THIRD_PARTY_LICENSES.txt` next to the exported `.exe`. It is deliberately **not** in the
`.pck` — inside the pck no player could read it, which defeats the purpose of a notices file.

Export output: `D:\otto_exp\otto-man.exe`. Uncheck "Export With Debug".

---

## 🎬 Açılış: Godot logosu kapalı, yerinde StudioSplash var

`application/boot_splash/show_image=false` — motorun kendi kocaman logosu artık çıkmıyor,
onun yerine düz siyah (`boot_splash/bg_color`) görünüyor. `run/main_scene` de
`res://scenes/StudioSplash.tscn`; One Percent Games logo animasyonu orada oynayıp
(~4.6 sn, herhangi bir tuşla atlanabilir) ana menüye geçiyor.

- Katmanlar `assets/logo/` altında ayrı PNG'ler: `white` (pil gövdesi), `red` (%1 göstergesi),
  `wordmark` (stüdyo adı) ve her birinin `* blur`'u. Hepsi 480x480 ve üst üste hizalı — sahne
  bunları üst üste bindirilmiş TextureRect'ler olarak tutuyor, animasyon sadece `modulate.a`
  sürüyor, hiçbir hizalama hesaplanmıyor.
- **`wordmark.png` / `wordmark blur.png` elle çizilmedi**, projenin kendi fontundan üretildi:
  Grenze (`main_font.ttf`) wght 900, "ONE PERCENT", punto 55, harf aralığı 4, blur sigma 4,
  480x480 tuvale, taban çizgisi eski `text.png` ile aynı banda oturacak şekilde. Yazıyı
  değiştirmek gerekirse **ikisini birlikte** yeniden üret; sadece birini değiştirirsen ışıma
  ile yazı ayrışır. Eski elle çizilmiş `text.png` / `text blur.png` artık kullanılmıyor
  (dosyalar duruyor, silinebilir).
- Yazının ışıması bilerek **gerçek Gaussian blur**, Godot'un `outline_size`'ı değil: kontur
  sert kenarlı çıkıyor ve pilin yumuşak blur'larının yanında çıkartma gibi duruyor. Denendi,
  atıldı.
- Blur katmanları **toplamalı (additive) CanvasItemMaterial** ile çiziliyor; siyah zeminde
  ışık saçma hissini veren şey bu. `Mix`e çevirirsen sadece bulanık bir kopya olur.
- `texture_filter = 2` (Linear) bilinçli: proje geneli `default_texture_filter=0` (Nearest)
  ama bu logo piksel art değil, blur'lar Nearest ile basamaklanıyor.
- Zamanlama Inspector'dan ayarlanır: `Logo Size`, `Glow Strength`, `Speed Scale`, `Hold Duration`,
  `Fade Out Duration`. En pratiği `Speed Scale` — tüm akışı birden hızlandırır/yavaşlatır.
- Splash menüye `get_tree().change_scene_to_file()` ile geçer ve `SceneManager.previous_scene_path`'e
  **bilerek dokunmaz**: `MainMenu._should_play_cold_start_fade()` onun boş olmasına bakarak soğuk
  açılış akışını (dil kapısı → erken erişim uyarısı → AI teklifi → profil kapısı → siyah fade)
  oynatıyor. Orayı doldurursan ilk açılış akışı tamamen kaybolur.
- `SceneManager.current_scene_path` ise menüye geçerken elle düzeltilir (`MentorObjectiveUI` gibi
  yerler "menüde miyiz" diye ona bakıyor).
- Açılış sahnesi artık menü olmadığı için `SoundManager`'ın kendi bootstrap'i menü profilini
  yakalayamaz; menü müziğini `MainMenu._ready()` içindeki `play_ambient_for_scene(scene_file_path)`
  çağrısı istiyor. O satır silinirse menü müziği hiç başlamaz.

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
  (`%APPDATA%\Rogue Harem\models\` — see the user-dir section below). Never next to the exe — that folder is
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

  **🔴 Adding a row to `strings.csv` is NOT enough — the `.translation` files must be reimported.**
  Until then `tr("your.new.key")` returns the key itself, and if the call site does
  `tr(key) % [...]` you get `not all arguments converted during string formatting` and a garbage
  label instead of an obvious missing-key error. Reimport headlessly after every CSV change:
  ```bash
  "…\Godot_v4.3-stable_mono_win64_console.exe" --headless --path . --import
  ```
  `localization/strings.{tr,en}.translation` are tracked in git and must be committed with the CSV.
- **🔴 `InputManager.apply_keyboard_preset()` ERASES every keyboard event on the actions it
  touches** (`_replace_action_keys`), so whatever `project.godot` binds is irrelevant for those
  actions. This silently cost the arrow keys in every menu: `wasd_numpad` rebound
  `ui_left/right/up/down` to A/D/W/S only. `_apply_ui_navigation_fallback()` now re-adds
  arrows + Enter/Space/Escape after every preset so menus always work with what players reach for
  first. **Any new preset key must assume the whole action is wiped first.**
- **`interact` needs a letter key in every preset.** `wasd_numpad` bound it to Numpad 8 alone, so on
  a laptop or TKL keyboard the dedicated interact key did not physically exist; W only worked by
  accident, at the call sites that also check `ui_up` (`BaseInteractable`, `player.gd`). Both
  presets now list `KEY_W` **first** — the order matters, `get_action_key_name(&"interact")`
  returns the first key and that string goes into tutorial text.
- **`UiFontScale` (autoload) scales menu fonts, and MENUS ONLY.** A menu opts in with
  `register(self, panel)` in `_ready`; it stores each control's original `font_size` in `meta` so
  it can be re-applied any number of times without compounding, and it scales the fixed offsets of
  a centered `Panel` too (at 140% the text does not fit a 640x520 box otherwise). HUD, village
  resource bar and world map are deliberately out of scope. Setting lives in
  `settings.cfg [video] ui_font_scale`.
- **🔴 NEVER use `FileAccess.file_exists("res://….tscn")` — it is ALWAYS false in an export.**
  Godot converts text scenes to binary and packs them as `X.tscn.remap` plus the real `.scn`;
  there is no `X.tscn` entry in the pck file table at all, and `FileAccess.file_exists()` reads
  exactly that table (`PackedData::has_path`) without applying remaps. In the editor the real file
  is on disk, so the check passes and everything looks fine.

  This killed **every minigame in every exported build**: `MinigameRouter.start_minigame()` began
  with that guard, so woodcut, food, fruit, stone, water, the villager lockpick and the VIP duel
  all returned `false` before loading anything. On screen: walk up to a tree, the yellow highlight
  and the arrow hint appear, press interact, and **nothing happens, ever** — which is exactly what
  the first playtester reported and why they could not finish the tutorial. `city_level_generator`
  had the same guard on its chunk scenes.

  Verified 2026-08-31 by parsing the 2026-08-30 `otto-man.pck` file table (3715 entries):
  `res://ui/minigames/ForestWoodcutMinigame.tscn` is absent, only `.tscn.remap` is present.

  **The only trustworthy existence check for a `res://` resource is `load()` returning non-null.**
  Do not "harden" such code by adding a file check back.
- **🔴 An interactable's Area2D must match what the player SEES, not the sprite's origin.**
  `TreeInteractable` shipped with a 700x600 px tree drawn over a **64x128** trigger box whose lower
  half sat below the floor. The player capsule is only 22 px wide, so the whole interaction window
  was ~86 px on a tree that looks 700 px wide — the first playtester concluded chopping was broken
  and never finished the tutorial. Sizes now live in `INTERACT_AREA_SIZE` / `INTERACT_AREA_OFFSET`
  on each interactable (`.tscn` and the code fallbacks read the same constants) and are measured,
  not guessed: tree 240x220 (260 px window), bush 150x120 (160 px). `BaseInteractable`'s
  `interact_arrow_offset` defaults to `-64`, which is *inside* a tall sprite — set it per
  interactable so the hint floats above the art.
- **🔴 `DungeonRunState.sync_warmup_limits()` freezes once the run's warmup completion is
  recorded.** `DungeonProgress.get_max_segments_for_run()` returns `warmup_completions + 1`, so the
  moment `try_finalize_warmup_progress()` bumps that counter the *finished* run's target grows.
  `CampScene._handle_mid_run_selection()` calls it on the exit door **before**
  `change_to_world_map()` shows the report, so a 1/1 run was re-read as 1/2 and the report said
  "ERKEN ÇIKIŞ" for the one exit the player was forced to take. Never recompute an active run's
  limits from persistent progress after that progress has been written.
- **🔴 `TutorialManager.set_objective("")` does NOT clear the objective box if the text is already
  empty** — it early-returns and never emits `village_objective_changed`. `MentorObjectiveUI` is a
  **persistent CanvasLayer on `get_tree().root`** that survives scene changes and only listens to
  that signal, so it keeps showing the previous session's objective forever. Use
  `clear_objective()`, which always emits. `reset_session_flags()` used to null the field directly
  and that is exactly how "New Game → Skip Tutorial" still showed the forest's "Odun: 0/3" line.
- The 6-pass TP0-TP5 port into Godot is **DONE**. `docs/GODOT_NPC_LLM_ARCHITECTURE.md` still
  describes it as pending — that doc is stale on this point.

---

## 💾 Oyuncu verisi: `%APPDATA%\Rogue Harem\`

`application/config/use_custom_user_dir=true` + `custom_user_dir_name="Rogue Harem"` (2026-08-31).
Öncesinde `%APPDATA%\Godot\app_userdata\otto-man\` idi — yayınlanacak bir oyun için kötüydü:
"Godot" altında duruyordu, adı ürünle uyuşmuyordu ve adı otto-man olan başka bir Godot
projesiyle çakışırdı. **Bu tarihten önceki kayıtlar eski klasörde kaldı, oyun onları görmez.**

Altında ne var: `otto-man-save/` (profile_1..3, `save_*.json`, `active_profile.json`),
`settings.cfg` (ses/video/dil/kontrol preset'i/AI tercihi), `models/` (7.5 GB gguf), `logs/`.

**🔴 `user://` editör ile dışa aktarılmış sürüm arasında ORTAKTIR.** Aynı makinede editörde
oynayınca oluşan profiller, senin çalıştırdığın exe'de de görünür — bu bir export hatası
değil, Godot'un normal davranışı. Godot'ta bunu değiştiren bir komut satırı seçeneği de yok.

Bu yüzden **"oyun benim save'lerimle export ediliyor" diye bir şey yok.** 2026-08-31'de
`otto-man.pck`'nin dosya tablosu ayrıştırılarak doğrulandı: 3715 kaydın hiçbiri save verisi
değil, kodun tamamı `user://`'ye yazıyor, `res://`'e veya exe'nin yanına yazan tek satır yok.
Sıfırdan açılışı test etmek için user klasörünü geçici olarak başka bir ada taşı, oyunu
çalıştır, sonra oyunun oluşturduğu boş klasörü silip yedeği geri koy.

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
