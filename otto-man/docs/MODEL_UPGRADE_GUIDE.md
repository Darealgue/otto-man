# Moving Off Mistral-7B — Model Upgrade Guide

## Why upgrade

A full day of prompt/grammar/logit-bias iteration on Mistral-7B-Instruct-v0.2 fixed every
*structural* bug (crashes, runaway generation, narration leaks, junk symbols) but could not fix
one *reasoning* bug: the model conflates "this topic is a big deal in this NPC's life" with
"this exact exchange is new/significant right now" (e.g. asking Hasan to recall a story already
in his own History gets scored significant, because "boys" is a salient word from his History).
Four different prompt rewordings and a logit-bias sweep (0 to ±10) never moved this one case.
That specific failure — telling "same fact restated" from "new fact" — is a genuine reasoning
task, and 7B-class models are known to fall back on shallow word-overlap shortcuts instead of
real discrimination there. Bigger models don't have this specific ceiling as often.

## What the model actually has to do here (read before picking one)

Don't pick a model that's just "bigger." Pick one whose known strengths match this specific job:

- **TP1** — decide "is this new/lasting for this specific person" (real reasoning/discrimination,
  the exact thing that just failed), AND write one short in-character line (creative-but-constrained
  writing), AND hit a strict 2-line/quoted-line output format, in under ~2s.
- **TP2** — output only changed `Field: Value` lines, nothing else, ever. This is the most
  rule-bound of the three passes — pure structured-instruction-following, near-zero creativity.
- **TP3** — merge/deduplicate/contradiction-resolve a growing list of life events into fewer,
  cleaner lines. A distinct reasoning skill (compression + consistency), not language style.

So the ideal model is strong at **instruction-following and structured/logical reasoning**
specifically — general "is smart at chatting" reputation is not the same thing, and a model
famous for creative writing/roleplay is not automatically better at this job than Mistral was.

## Recommendation

### Primary pick: Qwen2.5-14B-Instruct (GGUF, Q4_K_M)

- Widely regarded (community benchmarks, not just vibes) as unusually strong at following
  complex multi-constraint system prompts and at structured/logical discrimination tasks
  relative to its size — directly the two things TP1/TP2 need most.
- 14B at Q4_K_M is ~9 GB on disk/VRAM. On a 12 GB card that leaves enough headroom for a
  16k context and OS/Godot overhead, but it is not generous — see "if it doesn't fit" below.
- License: Apache-2.0 for most Qwen2.5 sizes, but **check the exact model card on Hugging Face
  before shipping** — don't assume, confirm for the specific checkpoint you download.
- Downside: uses ChatML prompt format, not Mistral's `[INST]...[/INST]` — this project's prompt
  wrapping is currently hardcoded to Mistral format, so this requires a real (small, well-defined)
  code change, not just swapping a file. Covered below.

### Fallback pick: Mistral-NeMo-12B-Instruct (GGUF, Q4_K_M)

- Same `[INST]...[/INST]` prompt family as what's already wired up — **drop-in, no prompt-wrapping
  code changes needed.** Lower integration risk, lower effort tonight.
- Real step up from 7B → 12B, but Mistral's lineup is generally reputed stronger at fluent/creative
  text than at hard state-tracking/discrimination — may or may not clear the specific bug that
  motivated this switch. Worth trying first if you want a quick, low-risk sanity check before
  committing to the ChatML rewrite for Qwen.

**Suggested order:** try NeMo 12B first (cheap to test, ~20 minutes), re-run the TP1 checklists
against it. If Hasan/Katina/Rahel-style cases still fail, move to Qwen2.5-14B and do the ChatML
integration.

### Ruled out

- **Llama 3.1/3.3 70B** — needs ~40 GB+ even at Q4, won't fit a 12 GB card without offloading so
  much to CPU that the 2s/5s time budgets become impossible. Skip unless VRAM changes.
- **Anything ≥ 20B at Q4** — same VRAM math problem on a 12 GB card once you account for context
  and OS overhead. If VRAM headroom is tighter than expected in practice, drop to Q4_K_S or a
  smaller model rather than starving the context window.
- **Same-size lateral moves (Llama 3.1 8B, Gemma 2 9B)** — plausible mild upgrades, but the whole
  point here is escaping the reasoning ceiling that showed up today; staying in the 7-9B band
  risks hitting the same wall again for a mid-size time/effort cost.

## Step 1 — Download

Get the GGUF from Hugging Face (community quantizers like `bartowski` or `Qwen`'s own org
publish ready-made GGUFs — don't quantize from scratch, it's unnecessary work).

```
# Example (adjust filename/repo to whatever's current when you look):
# Qwen2.5-14B-Instruct-Q4_K_M.gguf   (~9 GB)
# or, fallback:
# Mistral-Nemo-12B-Instruct-2407-Q4_K_M.gguf  (~7.5 GB)
```

Download via browser, or `huggingface-cli download <repo> <file> --local-dir .` if you have the
CLI installed. Place the file at:

```
D:\OttoMan\otto-man\otto-man\models\
```

Same folder the current `mistral-7b-instruct-v0.2.Q4_K_M.gguf` lives in. **Do not delete the old
Mistral file** — keep it until the new model is verified working, so you can roll back instantly
by just flipping a path back.

## Step 2 — Update `tools/NpcDialogueDryRun/Program.cs` (test harness)

1. **Point at the new file.** Either pass it explicitly:
   ```
   dotnet run ... -- "D:\OttoMan\otto-man\otto-man\models\Qwen2.5-14B-Instruct-Q4_K_M.gguf" --tp1-checklist
   ```
   or set `OTTO_LLAMA_MODEL` env var to that path — both already supported, no code change needed
   just to point at a different file.

2. **If moving to Qwen (ChatML), the prompt wrapper must change.** Find `WrapMistralInstruct` —
   it currently wraps everything as `<s>[INST] ... [/INST]`. Add a new wrapper:
   ```csharp
   private static string WrapQwenChatML(string instruction)
   {
       return "<|im_start|>user\n" + instruction.Trim() + "<|im_end|>\n<|im_start|>assistant\n";
   }
   ```
   Then switch every call site that currently calls `WrapMistralInstruct(...)` to call the new
   wrapper instead (TP1 decide/speak, TP2, TP3, and the single-pass/base paths all go through
   this one function today — grep for `WrapMistralInstruct(` to find every call site).

   If moving to Mistral-NeMo instead — **skip this step entirely**, the existing wrapper is already
   correct for it.

3. **Re-check the EOS/special-token warning.** Every run so far has logged
   `special_eos_id is not in special_eog_ids` at model load — that was a Mistral-7B GGUF metadata
   quirk. A different model may or may not show this. If it's gone, the literal `</s>` leak we
   patched around should no longer be able to happen (verify with a few checklist runs rather than
   assuming).

4. **Sanity-check the grammar files still parse.** Nothing model-specific in the `.gbnf` files —
   they're enforced by llama.cpp's sampler, not by the model — but always confirm no crash with a
   short `--tp1-lab` run before trusting a full checklist pass.

5. **Run the full checklist suite** (`--tp1-checklist`, `--tp1-checklist2`, `--tp1-checklist3`,
   `--tp1-checklist4`) and specifically check the recall-own-History cases (Hasan, Katina, Rahel,
   Andreas) — that's the exact bug this upgrade is for. If those still fail, the upgrade didn't
   solve the problem and it's genuinely a training/fine-tuning matter, not a model-size matter.

## Step 3 — Update `autoload/LlamaService.cs` (real game)

1. **Model file name.** Find `NpcMergedModelFileName` and the base-GGUF resolution logic —
   update the filename constant(s) to point at the new model file.

2. **Prompt wrapping.** `WrapMistralInstruct` is called from inside `GenerateResponse` for every
   pass (base summaries, TP1/TP2/TP3 three-pass calls, everything). If you're moving to Qwen,
   this needs the same ChatML-wrapper swap as in Program.cs — and it needs to happen in **exactly
   one place** here since `GenerateResponse` is the single shared call site, so this is actually
   less error-prone to change than in the dry-run tool (fewer call sites to miss).

3. **VRAM/context settings.** Check `GpuLayerCount`, `ContextSize`, and batch-size constants —
   a 12-14B model at Q4 uses meaningfully more VRAM than the current 7B. If `LlamaService.cs` ever
   loads a second weights object simultaneously (merged-NPC-GGUF + base GGUF at once, see the
   `NpcSkipSeparateBaseGgufWhenMergedNpcGgufEnabled` logic), loading two ~9GB models at once will
   not fit a 12GB card — force single-model mode (`OTTO_NPC_USE_MERGED_GGUF` unset, which is
   already the default) rather than trying to run two big models simultaneously.

4. **LoRA/merged-NPC-GGUF assets are now obsolete.** Any existing trained LoRA adapter or merged
   NPC GGUF was trained against Mistral-7B's specific weights — it **cannot** be applied to a
   different base model's weights. If/when training comes back into scope, it'll need to be
   redone from scratch against whichever model you land on. Don't try to reuse the old adapter.

## Step 4 — Verify before trusting it

Do not assume "bigger model = fixed" — prove it:

1. Run all four `--tp1-checklistN` suites against the new model, note the score same way we did
   for Mistral (record in `TP1_CHECKLIST.md`).
2. Specifically watch: recall-own-History cases, bare-threat cases, timing (still ≤2s for TP1
   alone, ≤4-5s for the full 3-pass chain — a bigger model is slower per-token, confirm the
   budget still holds before going further).
3. Only after a clean run (or a clearly better one than Mistral's) should TP2/TP3 tuning resume
   against the new model — don't carry over Mistral-tuned bias/temperature values blindly, they
   were tuned for a different model's calibration and may need re-checking from scratch (same
   lesson as when the TP1 prompt rewrite made the old logit-bias values actively harmful).

## Rollback

If the new model is slower than the budget allows, or somehow worse on the checklist: revert the
model path/env var back to the Mistral 7B GGUF, revert the ChatML wrapper change if made (git
diff will show exactly what changed), keep the old Mistral file in place. Nothing about this
upgrade is destructive if the old file and old wrapper code are left alone until the new model is
proven better.
