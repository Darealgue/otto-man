# AI Villagers — Test Checklist

Run these when we sit down to debug. Note what fails and what the console said; that is usually
enough to find the cause without re-deriving anything.

**Group A** is testable right now, in the editor, alone. **Group B** needs the export work
(Phases 5-8) to be finished first.

---

## Group A — editor, testable now

### A1. Normal AI dialogue still works  ← most important
This is the one thing I could not verify myself. It proves the grammar loading rewrite
(`System.IO` → `Godot.FileAccess`) did not break inference.

1. Run the game normally. Model is in `otto-man/models/`, so AI should be on.
2. Walk up to any Worker villager, open the chat window, send a message.
3. **Expect:** a normal reply, same as before this work started.
4. **Watch the console for:** `Grammar file not found` or `was empty or unreadable`. Either means
   the grammar fix is wrong.
5. Send something meaningful (a real fact about yourself) and confirm it still lands in the
   villager's History/Diary panel. That proves the full TP0-TP5 chain still runs.

### A2. The disabled path
1. Quit the game. Rename `otto-man/models` to `otto-man/models_off`.
2. Run the game and open a villager.
3. **Expect:**
   - The window opens normally.
   - Info and Diary/History panels look exactly as they always did.
   - The text box and Send button are dimmed, and you genuinely cannot click or type in them.
   - One narration line appears where the villager's reply would be, revealed letter by letter,
     with **no** `Name :` prefix.
   - The line mentions "Ayarlar" / "Settings" and "Yapay Zeka Köylüler" / "AI Villagers" in quotes.
4. Close and reopen the window a few times. **Expect:** the line varies (there are 4).
5. Switch language in Settings and reopen. **Expect:** the line appears in the other language.
6. **Rename the folder back to `models` when done.**

### A3. The offer screen must NOT appear in the editor
While `models_off` is still renamed (so no model is present), start the game from the editor.

**Expect:** the language gate, then the In Development notice, then straight to the menu.
**No AI offer screen at any point.** If it appears in the editor, the editor/export guard is broken
and that is a blocker.

### A4. Nothing else changed
Play normally for a few minutes with the model back in place: village, forest, a dungeon run.
Nothing outside villager dialogue and battle narration should behave differently.

### A5. Battle narration fallback (optional, harder to trigger)
Needs a village attack to resolve while no model is present. If you have a quick way to force one,
**expect** a short in-world line about a missing chronicler instead of silence. Low priority —
skip it if triggering an attack is a hassle.

---

## Group B — after the export work is done

### B1. Export size
Export a Windows build. **Expect** roughly 300-600 MB, not 8 GB. If the `.pck` is enormous, the
`include_filter` change did not take.

### B2. Exported build with no model
1. Run the exported `.exe` on a machine with no model file.
2. **Expect:** language gate → In Development notice → **the AI offer screen appears.**
3. Read both languages of the screen and check the wording renders correctly and scrolls.

### B3. "Skip for Now"
1. Choose Skip. **Expect:** straight into the menu, game fully playable, villagers silent with the
   narration lines.
2. **Quit and relaunch. Expect: the offer screen does NOT appear again.**
3. Confirm `%APPDATA%\Godot\app_userdata\otto-man\settings.cfg` now has an `[ai]` section with
   `choice_made=true` and `enabled=false`.

### B4. "Download & Enable"
1. Fresh state (delete the `[ai]` section from `settings.cfg`), choose Download & Enable.
2. **Expect:** the game does not freeze; you can play immediately while it downloads.
3. Confirm the file lands in `%APPDATA%\Godot\app_userdata\otto-man\models\`.
4. **Expect** villagers to start talking when it finishes, without a restart.

### B5. Resume
Quit mid-download, relaunch. **Expect** it resumes rather than starting from zero.

### B6. Model already present
Put the `.gguf` in `%APPDATA%\...\models\` manually before first launch.
**Expect:** no offer screen, villagers talk immediately.

### B7. Settings toggle
Turn AI villagers off in Settings with the model present. **Expect** villagers fall back to the
narration lines. Turn it back on. **Expect** they talk again.

### B8. Second machine (Goku)
The original failure. Install somewhere Windows protects if possible.
**Expect** the download to succeed, because it now targets `%APPDATA%` rather than the exe folder.

---

## What to tell me when something fails

- Which item number.
- What you saw versus what the list said to expect.
- Anything in the console mentioning `LlamaService`, `Grammar`, `AiVillagers`, or `model`.
