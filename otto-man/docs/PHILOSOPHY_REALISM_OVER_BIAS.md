# Read this before you touch any NPC dialogue prompt

If you are an AI agent about to tune TP1, TP2, or TP3 for this project — read this whole
file first. It cost a full day and a model upgrade to learn. Don't re-learn it the hard way.

## The one rule

**Never bias the model toward an answer. Only ever make the model understand reality more clearly.**

If a decision (significant/insignificant, yes/no, believe/disbelieve) comes out wrong, the fix
is never "nudge the sampler," "add a logit bias," "tune the temperature to get more yeses,"
or "add a rule that specifically blocks this one case." The fix is always: **find the place
where your prompt's wording or flavor fails to convey what the real underlying situation is,
and say that more clearly.** If the prompt already says it clearly and the model still gets it
wrong, that's a real capability ceiling — worth a bigger model, worth training, never worth a
statistical thumb on the scale.

## Why bias is not just inelegant — it actively breaks the game

This game's real design goal is limitless: a player can try *anything* on any NPC. Convince a
whole village to start a "poop nation." Try to teach every NPC Dothraki. Something nobody
building this system will ever have specifically anticipated or tested for. There is no
finite list of scenarios to guard against, because the list is infinite by design.

The only thing that scales to infinite, untested, never-imagined player behavior is: **every
NPC reacts the way a real person — with their real Info, their real History, their real Mood,
their real age — actually would.** Some villagers would join the poop nation. Some wouldn't.
It depends on who they are, not on a rule we wrote for "poop nation" specifically, because we
never wrote that rule and never could.

A logit bias or "lean toward no" instruction doesn't teach the model anything about reality —
it just shifts a probability mass in one direction, for every case, forever, regardless of
context. It will "fix" the test case you're staring at right now and quietly break some other
interaction you haven't tested yet and never will, because bias has no concept of "this
specific person, this specific moment" — it's a blunt global nudge, and reality is not blunt
or global. Realism-grounded prompting scales to infinite unplanned cases *by construction*,
because it's always asking "what would this person really do," never "hit this target rate."

## The concrete case study: the word "game"

Early on, TP1 asked the model to decide "significance" for the character's "saved character
sheet (Info and History — the facts **the game** remembers about you)."

That single word — "game" — was a real, physical planted seed pointing the model toward
"this is a fictional performance to comment on," not "this is a real person's real memory."
It's not a coincidence that one of the weirdest failures we saw was a villager's line ending
in social-media hashtags like `#StorytellingGame` — the model was, in a very literal sense,
doing exactly what the prompt told it: treating this as a game to narrate about, not a life to
actually live.

We spent real effort chasing that as a sampling-glitch, a penalty-stack side effect, a grammar
gap — all real contributing factors, worth fixing on their own merits — but the actual root
was one word breaking the frame the entire prompt was supposed to hold. The fix wasn't a
sampler trick. It was rewriting the prompt to say, plainly: *you are a real person, not a
character in a story, not someone performing a role* — and dropping "game" entirely.

**The lesson: when a model's behavior feels "off," first go looking for a place where the
prompt's own words contradict the reality you're trying to simulate — not for a rule to add
or a bias to apply.**

## How we already knew the target, from day one

The very first TP1 prompt this project ever used opened with something like: *"You are a
31-year-old healthy and sad male blacksmith named John living in the 17th century."*

That sentence alone already told you the intended target: a real human being, in a real
historical setting, with a real mood and a real life — not a fantasy NPC reciting lore, not a
chatbot following rules. If a 17th-century villager hears about a two-headed lamb from the
village chief, whether they believe it, fear it, laugh it off, or shrug depends entirely on
*who that person is* — their age, their temperament, what they've lived through — exactly the
same way it would for a real person today hearing an implausible rumor from someone they trust.
That's not a special rule to write. That's just what "real person" already means, if the
prompt actually succeeds in making the model believe it's simulating one.

## The "significance" word itself may not be the perfect word

One concrete open lead: the recall-own-History bug (asking an NPC to retell something already
in their own life story gets wrongly marked "significant") may be partly caused by the word
**"significant"** itself. A topic can be significant *to a person's life in general* (losing a
parent, saving someone from drowning) without today's retelling of it being *new* or *changing
anything about them right now*. If the model conflates "this is a significant topic" with
"this moment is significant," the word "significant" — or however the concept is described —
may need a sharper, more precise real-world description that a genuine human wouldn't confuse:
something closer to "would you, this real person, need to update what you know about your own
life because of this exact moment — or are you just being reminded of something you already
carry?" Keep hunting for the exact words a real person would use to draw that line themselves,
rather than reaching for a rule, an example, or a bias to paper over the confusion.

## The rule covers code-side workarounds too, not just the sampler

The same logic that bans logit bias also bans "mechanical rule" fixes bolted on in code or in
a rigid prompt instruction — keyword checks, forced verbatim-echo rules, string matching,
"always do X" guardrails. These fail for the same underlying reason bias fails: they can't
know things only genuine understanding of the specific content can reveal.

Concrete case: TP3 (the pass that keeps a villager's History free of contradictions and
duplicates) sometimes needs to merge two OLD entries that were never related before — "won a
tournament," "broke his hip" — into one new entry, because a brand-new third fact ties them
together retroactively ("was given a title *because of* the tournament win and the broken
hip"). A rule like "always echo every untouched History entry back verbatim unless the new
fact obviously matches it" sounds like a safe guardrail, but it has no way to anticipate that
those two old entries were about to become related — only the new fact's actual content
reveals that. Any mechanical shortcut added to guard against a failure mode will also silently
foreclose the legitimate cases that look similar on the surface. The only fix that survives
contact with a case like this is describing the underlying concept clearly enough for the
model to reason about — not a rule, not a code-side check, no matter how reasonable it sounds
in isolation.

## Before you touch a prompt again, ask this

1. Does every sentence in this prompt sound like it's describing a **real person's real life**,
   or does any part of it sound like a game mechanic, a rulebook, a checklist, or fiction?
2. Is there a word (like "game," like maybe "significant") that could be read two ways — one
   realistic, one mechanical/fictional — where the model might be taking the wrong reading?
3. If the model still gets it wrong after the wording is genuinely as clear and honest as you
   can make it — is that a real capability ceiling (worth a bigger/better model), not a
   wording problem anymore? Don't reach for bias as a substitute for that honest conclusion.
4. Would this fix generalize to a player trying something nobody on this project ever
   imagined — or does it only work because it happens to match the exact test case in front
   of you? If it's the second one, it's not a fix, it's overfitting, and it will break later.
