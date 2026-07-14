# Godot-Side NPC/LLM Architecture — Reference Map

Written 2026-07-13, before porting the 6-pass (TP0-TP5) dialogue design (proven in
`tools/NpcDialogueDryRun/Program.cs`) into the real game. This file is the ground truth
for "how does it actually work today" — read it before touching `NPCDialogueManager.gd`
or `LlamaService.cs`.

Repo root for the Godot project: `otto-man/otto-man` (contains `project.godot`).
The dry-run console tool lives as a sibling at `otto-man/tools/NpcDialogueDryRun/Program.cs`.
**Both read the same `otto-man/otto-man/grammars/*.gbnf` folder** — confirmed identical,
not a copy. Porting the 6-pass design means wiring GDScript to grammar files that
*already exist on disk*, not authoring new grammars.

## ⚠ This is the final architecture — nothing here is a fallback option

Explicit user directive (2026-07-13): **the 6-pass system as tested in the dry-run tool
today — model, sampling/config levers, prompts, grammar files, which TP triggers which,
how outputs get parsed, the exact pass count — is the one true, final design.** It is not
one candidate among several. Everything this doc flags below as "stale/legacy/dead" (the
Godot 3-pass pipeline, `output.gbnf`/`tp1_dialogue.gbnf`/`tp2_ledger.gbnf`/`tp3_history.gbnf`,
the merged/LoRA Mistral-7B weight files, `grammars/dev_session_prompt.txt`, the
`grammars/prompts/` snapshot .txt files) is dead history from earlier things that were
tried and abandoned — **not to be reused, referenced as a fallback, or left half-wired
"just in case" during the port.** Delete or archive them out of the live path entirely
rather than keeping them reachable behind a flag, the way the current
`_NPC_DIALOGUE_THREE_PASS` const does for the old single-pass system.

---

## 1. Entry point: interact → dialogue on screen

1. `player/player.gd` — player's interaction Area2D overlaps an NPC's `InteractionArea`
   (`Worker.tscn`, node groups `["NPC","interactables"]`). On overlap:
   `VillageManager.active_dialogue_npc = parent_node`, shows the interact-prompt button.
2. Player presses "interact" (P/E/joypad). Two paths exist; the NPC one is a hardcode
   in `player.gd` (~line 298): `VillageManager.active_dialogue_npc._on_interact_button_pressed()`.
3. `village/scripts/Worker.gd: _on_interact_button_pressed()` → `OpenNpcWindow()`
   (~line 2522): lazily `$NpcWindow.InitializeWindow(NPC_Info)`, `nw.show()`, connects
   `NpcDialogueManager.dialogue_processed → Worker.NpcAnswered`, locks player movement
   via `Village_Player.set_ui_locked(true)`.
4. `ui/npc_window.gd` (attached to `NpcWindow`, a child Control inside `Worker.tscn` —
   **one instance per NPC, not a shared singleton window**) renders the chat UI. Player
   types + Enter/Send → `_submit_player_dialogue()` → appends to `Chat_log`, calls
   `NpcDialogueManager.process_dialogue(NpcInfo, text, npc_name)`.
5. `autoload/NPCDialogueManager.gd` runs the multi-pass pipeline (§3), emits
   `dialogue_processed(npc_name, final_state, generated_dialogue, was_significant)`.
6. `Worker.gd: NpcAnswered()` → `npc_window.gd: NPCDialogueProcessed()` — rewrites
   `NpcInfo`, refreshes diary panel, rebuilds chat log, re-enables Send (or dispatches
   a queued message if the player typed ahead while busy).
7. Close: `Worker.gd: CloseNpcWindow()` (close button or ESC via `InputManager`),
   disconnects signal, unlocks movement.

**Not every "NPC" goes through this.** `village/scripts/ConcubineNPC.gd` (harem
management) and `village/scripts/TraderVillageNPC.gd` (scripted trader dialogue) have
zero ties to `NpcDialogueManager`/`LlamaService`. Only `Worker` NPCs use the LLM pipeline.

---

## 2. LLM service layer — `autoload/LlamaService.cs`

Autoload singleton `LlamaService` (`Node, IDisposable`).

- **Model**: `Mistral-Nemo-Instruct-2407-Q4_K_M.gguf`, resolved at
  `res://models/` in-editor or next to the exe in exports (`OTTO_MODEL_DIR` /
  `C:\otto_exp` fallback). `ContextSize=16384`, `GpuLayerCount=99`,
  `Threads=Clamp(ProcessorCount,4,32)`, FlashAttention on.
- A second Mistral-**7B** merged/LoRA weight set exists on disk but is explicitly
  commented as **stale/incompatible** with the NeMo-12B base and is off by default
  (`OTTO_NPC_USE_MERGED_GGUF`). Don't enable it.
- **Public entry points**:
  - `GenerateResponseAsync(...)` — generic/non-NPC (quest text, battle summaries),
    uses `StatelessExecutor.InferAsync`.
  - `GenerateResponseAsyncNpc(prompt, maxNewTokens=350, useGrammar=true, temperature=0.8f, appendJsonObjectOutputFooter=true, grammarFileName="")`
    — the **only** method `NPCDialogueManager.gd` calls. Signal: `GenerationCompleteNpc`.
- **Execution model**: NOT `StatelessExecutor.InferAsync` for NPC calls — that stalls
  idle-GPU on long prompts inside Godot. Instead a synchronous, manually-chunked
  `LLamaContext.Decode` loop (`InferNpcUsingSharedContext`, 128-token chunks, tunable
  via `OTTO_NPC_PREFILL_CHUNK`), reusing one shared `LLamaContext`/`LLamaWeights`
  across calls. Runs inside `Task.Run(...)`, off the main thread; result marshaled back
  via `CallDeferred("emit_signal", ...)` — so the pipeline never freezes the game.
- **Sampling**: JSON mode gets a +6.0 logit bias on `{`. TP1-dialogue-only calls get
  anti-repetition sampling (`RepeatPenalty 1.18/FreqPenalty 0.85/PresPenalty 0.5/PenaltyCount 256`)
  — deliberately **not** applied to significance/info/history passes, since a yes/no or
  field-diff judgment must only be steered by prompt wording, never by the sampler.
- **Chat wrapping**: `WrapMistralInstruct()` — if the body already has its own
  `[INST]...[/INST]` (TP2/TP3-style), just prepends `<s>`; for plain dialogue (no
  JSON footer), wraps as `<s>[INST] body [/INST]` with no trailing reminder (matches
  training format exactly); otherwise (legacy path) appends a "Return ONLY the JSON..."
  footer.
- Grammar loading: `res://grammars/<grammarFileName>.gbnf` (falls back to `output.gbnf`).

**Takeaway: `LlamaService.GenerateResponseAsyncNpc` needs NO changes to support the
6-pass port** — it's already parameterized per-call by grammar file, temperature,
token budget, and JSON-footer toggle. All porting work is in `NPCDialogueManager.gd`.

---

## 3. Prompt orchestration — `autoload/NPCDialogueManager.gd`

**Godot ships a 3-pass pipeline today — an earlier ancestor of the dry-run tool's
6-pass design, not a subset of it.** `const _NPC_DIALOGUE_THREE_PASS := true` (~line 34)
gates this; the old single-pass legacy path is still present but unreachable while
this flag is true (see Stale Things, §9 item 2).

### Pass 1 (combined TP0+TP1) — `_construct_three_pass_prompt_1()`
One completion produces BOTH `Significant: yes/no` (decided first) AND
`Generated dialogue:` (spoken second), grammar `tp1_dialogue.gbnf`.
**Known bug this reproduces**: judging significance before the dialogue exists lets a
vivid retelling leak back and poison the yes/no pick. The dry-run tool fixed this by
splitting into TP0 (speak first, `tp1b_dialogue.gbnf`) → TP1 (judge significance
against the line actually spoken, `tp1a_significance.gbnf`) — Godot still has the bug.

### Pass 2 (combined TP2+TP3) — `_construct_three_pass_prompt_2()`, only if Pass 1 said yes
One completion emits BOTH Info-field deltas (Name/Occupation/Mood/Health/Age/History)
AND at most one History candidate line together, grammar `tp2_ledger.gbnf`, temp 0.55.
The dry-run tool split this into TP3 (history-candidate, `tp3_history_candidate.gbnf`)
running **first**, then TP2 (info-fields-only, `tp2_info_only.gbnf`) running **second**
with TP3's candidate fed in as context — fixes a "premature firing" bug where TP2 had
to independently re-derive a judgment TP3 was already better at.

### Pass 3 (old TP4+TP5 combined, no safety net) — `_construct_three_pass_prompt_3()`, only if Pass 2 changed History
One completion rewrites the **entire History array** in one shot (decide: contradicts?
finishes? connects two entries? else append new) — grammar `tp3_history.gbnf`, temp 0.35.
**No verification that the model didn't corrupt an untouched entry.** The dry-run tool
replaced this with TP4 (relation-gate: does the candidate relate to entry N? —
`tp4_select_index.gbnf`, the quote-based `tp4_select_quote.gbnf` variant was tried and
found worse) → TP5 (merge: `tp5_merge_narrow.gbnf`, given ONLY the selected entry/entries,
never the full list) → and critically, `ApplyTp5QuoteMergeReplace`-style code requires
an exact verbatim match before overwriting anything; every non-matched entry is passed
through by code untouched, never regenerated by the model.

### Grammar files that exist on disk but Godot never loads
`tp1a_significance.gbnf`, `tp1b_dialogue.gbnf`, `tp2_info_only.gbnf`,
`tp3_history_candidate.gbnf`, `tp4_relation.gbnf`, `tp4_select_index.gbnf`,
`tp4_select_quote.gbnf`, `tp5_merge.gbnf`, `tp5_merge_narrow.gbnf` — these are the
concrete, already-tuned artifacts of everything proven in the dry-run tool. Porting is
about wiring GDScript calls to these files in the right order, not authoring anything new.

---

## 4. NPC data model

Plain `Dictionary`, no custom Resource class:
```gd
{
  "Info": {"Name":String, "Occupation":String, "Mood":String, "Health":String, "Age":String, "Gender":String},
  "History": [String, ...],
  "Latest_news": [String, ...],
  "Chat_log": [{"role":"player"|"npc", "speaker":String, "text":String}, ...]
}
```
A legacy `History_summary` field is actively `.erase()`d wherever encountered — memory
lives entirely in the `History` array now, by design (see `grammars/prompts/NPC_HISTORY_MEMORY_DESIGN.txt`).

- **Runtime home**: `Worker.NPC_Info : Dictionary` (`@export var` on `Worker.gd`),
  duplicated into `npc_window.gd.NpcInfo` when the chat window opens.
  `NPCDialogueManager` holds a transient copy only for one in-flight turn.
- **Seed pool**: `autoload/Villager_AI_Initializer.gd` (`VillagerAiInitializer`)
  hardcodes a ~100-entry `Villager_Info_Pool` of hand-written Ottoman-village NPCs.
  `get_villager_info()` pops a random entry for a newly-spawned `Worker`.
- **Persistence**: `Save_Villager_Info()` appends to `VillagerAiInitializer.Saved_Villagers`,
  written to `user://otto-man-save/Saved_Villagers.json` via `save_array_to_json()`.
  `autoload/SaveManager.gd` pulls this into the aggregate game save
  (`get_saved_villagers_copy()`/`get_villager_pool_copy()`). `Load_existing_villagers()`
  migrates legacy shapes on load and removes loaded villagers from the fresh-spawn pool.

### ⚠ Open gap: `Latest_news` (village notice-board flavor) is wired but never actually tested

`Latest_news` is a real field on every NPC in the live game (§4's dict shape,
`update_latest_news()` in `Villager_AI_Initializer.gd`), meant purely as flavor: something
for an NPC to bring up on a bare "hello, how's it going?" instead of having nothing to say.
It exists precisely for that low-content-input case — and that's exactly the case the
6-pass system's own testing never covered.

Traced through `Program.cs` (the code the port will draw its prompt bodies from):

- **TP0** (`Tp1SpeakBody`, the live speak pass) receives raw news text directly —
  `"News you've heard on the village notice board: %%NEWS%%"` — and is expected to let
  it flavor small talk.
- **TP1** (`Tp1MinimalSignificanceBody`, the live significance gate) does **not** receive
  raw news at all. It only sees the chat transcript and the line TP0 just spoke, and must
  rely on its existing item 4 ("about someone else, not really about this person's own
  life — answer no") and the "story or rumor about someone else... doesn't count" clause
  to correctly treat a news-flavored reply as insignificant.
- **TP2/TP3/TP4/TP5 never receive `Latest_news` at all.** The only way news content could
  reach them is indirectly — if TP0's news-flavored line ends up in the chat log, which
  IS fed forward into every later pass.

This design is plausible on paper but **has never actually run**: every NPC across this
session's whole interactive-testing arc (Boris, Emine, Anahit, İbrahim, Vartan, Mariam)
started with an empty `Latest_news`, defaulting to "nothing new" — the news-flavor path
in `Tp1SpeakBody` was never exercised with real content in any live conversation. (Older,
pre-pivot *scripted* test scenarios in `Program.cs`, e.g. the "NOTICE-BOARD NEWS ONLY"
cases around lines 1375-2571, did drill TP1's rumor-vs-personal-fact distinction — but
against an earlier version of the pipeline, and never through a real back-and-forth
conversation the way the final testing methodology requires.)

The specific, concrete risk (why this is worth being cautious about, not just an
oversight to shrug off): this session's other real bugs all came from exactly this shape
of indirect leakage — TP3's "repeating it back" echo-fabrication bug, TP5's
distractor-context bug fixed by narrowing what it's shown. A villager casually mentioning
notice-board news in dialogue is precisely the kind of content that could get
mistakenly promoted into a permanent History entry by TP3, or wrongly flip TP1 to "yes"
if a news item happens to graze something the NPC's own History already talks about.

**Before or during the port, this needs a real interactive test**: pick an NPC, populate
`Latest_news` with a plausible notice-board line, open with a bare "hello, how's it
going?" or similar low-content greeting, and verify — with raw TP0-TP5 output pasted
literally, per the standing testing discipline — that (a) TP0 uses the news naturally as
flavor without over-committing to it, (b) TP1 correctly stays "no" on the news-flavored
reaction alone, and (c) if the player then pushes further on the news topic, TP1/TP3
correctly distinguish "reacting to gossip" from "something that actually changed about
this NPC's own life." Do not assume the untested design is safe just because the
plumbing already exists.

---

## 5. UI layer

`ui/npc_window.tscn` + `ui/npc_window.gd`, instanced as a child Control inside each
`Worker.tscn` (one per NPC). Tabs: `DialogueWindow` (chat log + `ChatLineEdit` +
`SendButton`), `DiaryWindow` (renders `History` as Labels), plus unrelated
`DutiesWindow`/`MissionWindow`.

- Submit → `_submit_player_dialogue()` → `NpcDialogueManager.process_dialogue()`.
- If the manager is already busy (`is_npc_dialogue_busy()`), the player's line is
  **queued** (`_pending_player_turns`, shown in UI immediately but not sent) and
  dispatched once `dialogue_processed` fires — not dropped, not blocked outright.
- **Only one NPC conversation can be in flight globally** —
  `NPCDialogueManager._current_processing_npc` is a single string, not per-NPC. A
  second NPC's call while busy gets rejected with "Please wait a moment...".
- A "significant" turn is **3 sequential LLM round-trips** (Pass1→Pass2→Pass3), each
  a few seconds — total latency is the sum. Porting to 6 passes will roughly double
  worst-case turn latency (6 round-trips instead of 3) — worth keeping in mind for UX
  (loading indicator, whether the player can still queue a next line meanwhile).

---

## 6. Configuration — levers and gauges (all hardcoded constants + env-var overrides, no config Resource/Project Setting)

| Lever | Where | Value |
|---|---|---|
| Model file | `LlamaService.cs: DefaultModelFileName` | `Mistral-Nemo-Instruct-2407-Q4_K_M.gguf` |
| Context size | `LlamaService.cs: Initialize()` | 16384 |
| GPU layers | `LlamaService.cs: Initialize()` | 99 |
| Merged/LoRA NPC weights | env `OTTO_NPC_USE_MERGED_GGUF` | **dead — not part of the final design; delete the .gguf files and this code path during the port, don't just leave it off** |
| Sync-decode chunk size | env `OTTO_NPC_PREFILL_CHUNK` | 128 (32-4096) |
| VROOM/InferAsync path | env `OTTO_LLAMA_VROOM` / `OTTO_NPC_USE_INFER_ASYNC` | off |
| NPC temperature (Pass1/2) | `NPCDialogueManager.gd: _NPC_TEMPERATURE` | 0.55 |
| NPC temperature (Pass3) | `NPCDialogueManager.gd: _NPC_TP3_TEMPERATURE` | 0.35 |
| Max tokens per pass | `_NPC_TP_TOKENS_1/_2/_3` | 280 / 160 / 520 |
| Grammar on/off per pass | `_NPC_TP1_USE_GRAMMAR` etc. | all true (legacy `_NPC_USE_GRAMMAR` false) |
| Chat-log context window | `_CHAT_LOG_PROMPT_MAX_MESSAGES` | 12 |
| Debug trace | `_LOG_NPC_DIALOGUE_CHAIN := true` | prints full prompts/completions + chain events |

---

## 7. Autoloads (`project.godot [autoload]`), NPC/LLM-relevant subset

- **`LlamaService`** (`autoload/LlamaService.cs`) — model/inference wrapper (§2).
- **`NpcDialogueManager`** (`autoload/NPCDialogueManager.gd`) — prompt construction,
  pass orchestration, parsing, state merge (§3). **This is the file to edit for the port.**
- **`VillagerAiInitializer`** (`autoload/Villager_AI_Initializer.gd`) — seed pool,
  save/load of `Saved_Villagers.json` (§4).
- **`VillageManager`** (`village/scripts/VillageManager.gd`) — spawns `Worker`s, holds
  `active_dialogue_npc`, bridges to `SaveManager`.
- **`SaveManager`** (`autoload/SaveManager.gd`) — aggregate game save, includes villager data.
- **`InputManager`** — interact-key label, ESC/cancel checks for closing dialogue window.
- Note: `LlamaService.GenerateResponseAsyncBase` also serves a "battle-story LLM"
  (`_DISABLE_BATTLE_STORY_LLM`, likely `WorldManager`) — a second consumer of the same
  base weights, unrelated to NPC dialogue but sharing the same service/context.

---

## 8. Porting checklist — 3-pass (shipped) → 6-pass (proven in dry-run tool)

All target grammar files already exist in `grammars/`. Work is entirely in
`NPCDialogueManager.gd`:

1. **Split Pass 1** into two sequential `GenerateResponseAsyncNpc` calls: speak first
   (`tp1b_dialogue.gbnf`) → then judge significance against the actual spoken line
   (`tp1a_significance.gbnf`). Fixes the "vivid retelling poisons significance" bug.
2. **Reorder + split Pass 2**: compute the history candidate first
   (`tp3_history_candidate.gbnf`), feed that candidate into the info-only pass
   (`tp2_info_only.gbnf`) as context. Replaces the single `tp2_ledger.gbnf` call.
3. **Replace Pass 3** with TP4 (relation-gate, `tp4_select_index.gbnf` — NOT the quote
   variant, which regressed to 0/10 on unrelated/multi-relation cases in dry-run testing)
   → TP5 (`tp5_merge_narrow.gbnf`, given only the selected entry/entries). Port the
   quote-verified-replace safety logic (exact-match before overwrite, untouched entries
   passed through by code) from the dry-run tool's `ApplyTp5QuoteMergeReplace`/
   `ApplyTp4SelectedMerge` into GDScript.
4. `LlamaService.cs` needs no changes — already parameterized correctly per-call.
5. Consider UX impact of 6 round-trips vs 3 (roughly 2x worst-case latency per
   significant turn) — may want a visible "thinking..." state per pass, not just one
   spinner for the whole turn.
6. Port prompt bodies verbatim from `Program.cs` (`Tp1MinimalSignificanceBody`,
   `Tp3HistoryCandidateBody`, `Tp4SelectIndexBody`, `Tp5MergeNarrowBody`, etc.) — these
   have been through many rounds of live-tested fixes; don't rewrite them from scratch
   in GDScript.
7. **Delete, don't just bypass, everything superseded**: the old
   `_construct_full_prompt()` legacy single-pass path and its `_NPC_DIALOGUE_THREE_PASS`
   flag, the now-unused `tp1_dialogue.gbnf`/`tp2_ledger.gbnf`/`tp3_history.gbnf`/
   `output.gbnf` grammars, the stale Mistral-7B merged/LoRA `.gguf` files and their
   loading code, `grammars/dev_session_prompt.txt`, and the `grammars/prompts/`
   historical snapshot `.txt` files. These are not fallbacks to keep reachable — see
   the final-architecture note at the top of this doc.
8. **Test the `Latest_news` path for real** (§4's open-gap subsection) before calling
   the port done — it's part of the final design's prompts but has never been run with
   actual news content in the interactive-conversation testing style this project uses.

---

## 9. Stale / dead / inconsistent things — delete these during the port, don't preserve them

Per the user's explicit final-architecture directive (top of this doc), none of the
following are options to keep around "just in case" — they're artifacts of earlier
things that were tried and superseded, and should be removed from the live path
entirely once the 6-pass port is in:

1. `grammars/dev_session_prompt.txt` (which `LlamaService.cs`'s own header comment
   points to) describes the **legacy single-pass JSON** design as if current. Delete it
   or replace it with an onboarding doc describing the actual final 6-pass design —
   don't leave it as a misleading artifact.
2. The legacy single-pass path (`_construct_full_prompt()`, `output.gbnf`) is still
   fully wired in `NPCDialogueManager.gd`, just unreachable while
   `_NPC_DIALOGUE_THREE_PASS := true`. Remove this code and the flag entirely during
   the port rather than leaving it dead-but-reachable.
3. Stale Mistral-7B merged-GGUF/LoRA files and their loading code
   (`OTTO_NPC_USE_MERGED_GGUF`, `NpcDialogueUseMergedNpcGguf`,
   `NpcDialogueUseLoraAdapterGguf`) are not part of the final design — the final
   design is the plain base Mistral-NeMo GGUF only. Delete the `.gguf` files and this
   code path, don't just leave the toggle off.
4. `grammars/prompts/` holds ~6 historical prompt-snapshot `.txt` files (CANONICAL_BACKUP,
   SHIPPED_LEGACY, v2_DRAFT, etc.) from earlier prompt generations — dead history, not
   reference material to consult while porting. The only live prompt source is
   `Program.cs`'s current TP0-TP5 body constants.
5. `grammars/NPC_DIALOGUE_MULTI_PASS_TEST_PLAN.txt` and the old 3-pass design in
   `NPCDialogueManager.gd` itself are both superseded by the 6-pass port — once ported,
   delete this doc and the old pass-construction functions rather than leaving them
   alongside the new ones.
6. `village/scripts/ConcubineNPC.gd` and `TraderVillageNPC.gd` are NPC-like but
   intentionally outside the LLM dialogue system — this one is NOT stale, just a
   reminder that not every "NPC" group member goes through `NpcDialogueManager`.
