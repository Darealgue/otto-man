# Marketing Plan

Status: game is feature-complete (platformer combat, combos, roguelike skills,
boss fights, LLM-driven village/NPCs, hex-grid world map, resource minigames).
No marketing has happened yet — page, socials, and content all start from zero.
Solo effort (dev), zero budget, no AI-generated content of any kind. Art is
Goku's, in his established pixel-art style — no MS-Paint/sketch style on any
public-facing asset.

Capacity: ~1 week fully available right now, dropping to a few afternoon hours
after that (pending a possible day job). Plan the sequencing below assuming the
first week is spent on the highest-leverage, hardest-to-parallelize item —
getting the Steam page assets moving with Goku — since everything else stalls
without it.

---

## Phase 0 — Foundations (decide before anything public goes out)

- **Title**: "Rogue Harem" has never been made public — still changeable.
  Not resolved in planning; keep as an open decision, revisit once art starts
  taking shape (a piece of key art often clarifies whether a name fits).
- **Positioning (locked in)**: two parallel content tracks, not one blended one.
  - **Safe track** (TikTok, YT Shorts, Instagram Reels): mechanics, LLM-NPC
    moments, comedy — never text/say the title on this track, let a logo card
    carry the name instead, so no classifier ever reads "harem" out of a
    post's own text/audio. See Phase 3 for why.
  - **Expressive track** (X/Twitter, Discord, Steam page itself): full title
    used freely, character art shown, community that expects and wants this
    content lives here.
  - The one shared surface: whatever capsule/header image is likely to appear
    as an auto-generated link-preview thumbnail on the safe-track platforms
    (Header/Small Capsule) should be a clean, non-suggestive piece — the
    spicier art belongs further down the page (screenshots) and on the
    expressive track, not in the thumbnail that unfurls inside a TikTok/Insta
    post.
- **"AI" framing (locked in)**: never lead with the word "AI" or "AI-powered"
  as a badge. Sell the LLM-NPC system by showing outcomes ("I told this
  villager something dumb three days ago and it just brought it back up"),
  never by labeling the tech. If it comes up, it's a strength that the art is
  100% hand-drawn (Goku) — "art is fully human, the LLM system is dialogue
  only" flips the usual AI-slop suspicion into a differentiator.
- **Steam content survey**: fill it out honestly (mature content descriptors +
  AI-disclosure section, required since 2024) when the page is created. Small
  compliance step, not a marketing decision.

## Phase 1 — Store assets (the actual blocker for everything else)

Goku is doing all art, in his real pixel-art style — no placeholder/sketch art
ships publicly. Dependency risk: if Goku is unavailable, no AI fallback is
acceptable per explicit instruction — the honest fallback is "this phase
slips" until another non-AI option is found. Flag this openly rather than
papering over it with a fake date.

Checklist (current, verified Steam specs as of this plan):

| Asset | Size | Notes |
|---|---|---|
| Header Capsule | 920×430 | Featured sections — keep this one "safe" (see Phase 0) |
| Small Capsule | 462×174 | Search results (auto-generates 184×69, 120×45 — must read at that size) |
| Main Capsule | 1232×706 | Homepage carousel |
| Vertical Capsule | 748×896 | Sale pages |
| Library Capsule | 600×900 | Post-wishlist/owned library |
| Library Hero | 3840×1240 | 860×380 center = safe area; **no text** in this image |
| Library Logo | 1280×1280 (or scaled) | Transparent PNG, logotype only |
| Page Background | 1438×810 | Optional — auto-generated from screenshots if skipped |
| Screenshots | min 1920×1080, 16:9 | **Minimum 5**, real gameplay only (not concept art), 4+ marked all-ages |
| Trailer | — | At least one, hosted on YouTube |

Order of attack: logo + one Header/Small Capsule pair first (unblocks page
submission), then screenshots (pull straight from real gameplay, easiest
lift), then the remaining capsule variants, trailer last (needs the most
finished-looking footage, benefits from having screenshots already picked).

## Phase 2 — Steam page goes live (as soon as Phase 1's minimum set exists)

No demo required to go live — the page can go up and start collecting
wishlists on its own well before any Next Fest. Submit for review as soon as
logo + capsules + 5 screenshots + trailer exist (review lag can run 2+ weeks
for a first page — start this the moment assets are ready, don't batch it
with later polish).

Once live: this is the single CTA every piece of content points to, per the
original plan. No content goes out before this exists.

## Phase 3 — Content engine (starts once the page is live)

**Safe track** — TikTok / YT Shorts / Instagram Reels. Primary format is the
Vedinad/danidev template, adapted:
1. Open with a real Reddit/Discord comment ("add X" or "I broke your game by
   doing X").
2. Test it in-game, show the funny result (bug-turned-feature or a failed
   attempt).
3. Quick edit: "this comment changed the game, now it's official."
4. CTA to wishlist — logo card, no spoken/written title (Phase 0 rule).

**Expressive track** — X/Twitter, Discord, Steam page. Character art posts,
#ScreenshotSaturday, #IndieGameDev, #WishlistWednesday, dev-process threads,
full title used freely.

**Process content** — devlogs (YouTube long-form), Reddit dev-process posts.
This is also where Goku's rough concept sketches (the MS-Paint doodles) belong
— paired with the finished sprite/scene as a "how it started / how it's
going" post, not used as standalone presentation art. Doubles as evidence the
work is genuinely hand-crafted, reinforcing the AI-framing point from Phase 0.

**Platform → content map**

| Platform | Track | Content |
|---|---|---|
| TikTok / YT Shorts / IG Reels | Safe | Vedinad-template clips, no title text/audio |
| X/Twitter | Expressive + process | Character art, screenshots, #ScreenshotSaturday/#IndieGameDev/#WishlistWednesday, dev threads |
| Discord (own server) | Both | Community home base, early builds, patch notes |
| Discord (other servers) | Safe | Godot showcase channels, indie-dev communities, where self-promo is allowed |
| Reddit | Safe/process | r/IndieGaming, r/IndieDev, r/gamedev (process posts, not promo), r/playmygame, r/pixelart |
| YouTube (long-form) | Process | Devlogs — trust-building, shows real dev process |
| itch.io | Both | Secondary storefront, more tolerant of character art; option to host an early free demo before the Steam demo exists |
| Steam (as a channel) | — | Curator key outreach once a demo exists, tag optimization |
| Press/streamers | — | Needs a press kit once assets exist; small/mid streamer key outreach |

Cadence: match to actual capacity — front-load content creation during the
full-time week (batch-record/edit multiple Shorts at once), then a sustainable
afternoon-hours cadence after (e.g. 2-3 posts/week on the safe track rather
than daily, to avoid burnout-driven quality drop).

## Phase 4 — Milestone targeting

Steam Next Fest: **June 2026 has already passed. October 19-26, 2026** is the
next one (registration closes Aug 31, demo due Sept 21) — technically
reachable but tight given zero existing art assets and the drop to part-time
capacity after week one. Recommendation: don't rush a demo for October at the
cost of quality — a Next Fest slot is close to a one-shot exposure event and
isn't worth burning on a rushed build. Target the **edition after October**
(next confirmed slot: February 2027) for the demo push, while the Steam page
itself goes live independently, well before that, per Phase 2.

Revisit this date once Phase 1 has a real timeline from Goku — this is the
single most schedule-sensitive assumption in the whole plan.

## Ongoing — community & metrics

- Stand up the Discord server once the page is live (Phase 2), not before —
  nothing to gather people around yet.
- Track wishlist count and wishlist conversion rate as the real metrics, not
  views/likes — a viral clip with no wishlist follow-through isn't success.
  Compare wishlist adds against the Vedinad-style test performed in Phase 3's
  actual template, since the last step of every video is the CTA.
