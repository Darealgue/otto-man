Prompt + merged-model safety nets (NPC dialogue refactor workflow)
================================================================

1) RUNTIME PROMPT (actual shipped template)
   - Source of truth: autoload/NPCDialogueManager.gd → _construct_full_prompt
   - Git-recovered **Player Dialogue** + significance rules + Latest_news:
     NPC_DIALOGUE_PROMPT_git10487f4_PLAYER_DIALOGUE_WITH_LATEST_NEWS.txt (commit 10487f4 + Recent conversation graft)
   - **Do not edit:** frozen baseline before micro-tweaks → NPC_DIALOGUE_PROMPT_READ_ONLY_FROZEN_git10487f4_PRE_MICRO_TWEAKS.txt

2) OTHER SNAPSHOTS (not necessarily wired)
   - NPC_DIALOGUE_PROMPT_CANONICAL_BACKUP.txt — long STATEFUL PERSONA ENGINE template (Incoming-dialogue era reference).
   - NPC_DIALOGUE_PROMPT_SHIPPED_LEGACY_PRE_STATEFUL_ENGINE.txt — short bullet prompt ("Incoming dialogue").
   - Oldest Player-line-inside-JSON + examples: NPC_DIALOGUE_PROMPT_git437a38f_PLAYER_DIALOGUE_IN_JSON_BLOCK.txt

3) BEFORE RISKY EDITS
   - Copy the active template from NPCDialogueManager.gd to a dated filename.

4) PROMPT SOURCE OF TRUTH (draft — experimental)
   - NPC_DIALOGUE_PROMPT_v2_DRAFT.txt — design iterations; sync into .gd only when promoting.

5) REVERT PROMPT IN CODE
   - Pick the snapshot file above and paste its template into NPCDialogueManager.gd _construct_full_prompt (preserve % ordering
     and substitutions; duplicated blocks may repeat the five values twice).

6) HISTORY MEMORY DESIGN (no History_summary field)
   - See NPC_HISTORY_MEMORY_DESIGN.txt — long History allowed; compression is inside History[]
     via model edits, not a separate prose field.

7) KEEP OLD LORA + MERGED GGUF (do not overwrite in place)
   Under res://models/ (repo: otto-man/otto-man/models/) keep dated copies, e.g.:
     mistral-7b-instruct-v0.2-NPC-merged.Q4_K_M.gguf
       → copy/rename to ...-NPC-merged_PRE_REFACTOR_YYYY-MM-DD.Q4_K_M.gguf
   Adapter checkpoints (if you keep separate LoRA files): same idea with suffix/date.
   Point LlamaService.cs / filenames at the experimental merged file only after backup.

8) TEST ORDER (recommended)
   - Base GGUF + new prompt (compare to what you know about base + old prompt).
   - Then new merged GGUF trained on aligned data when ready.
   - Keep old merged available for A/B.

See also: grammars/dev_session_prompt.txt (agent onboarding)
           docs/LLAMASHARP_CUDA_WINDOWS_MERGED_NPC_SESSION.md (CUDA / merged notes)
