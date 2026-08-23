# Road to Published Game

A literal checklist, in the order you actually do it. Every item is a concrete action —
no "go check another file," everything you need to know is written right here. Check items
off top to bottom; where things run in parallel, that's called out explicitly. Optimized
entirely around money: pre-launch wishlist count/velocity and launch-week visibility, because
those two numbers are what actually determine lifetime revenue on Steam.

---

## STAGE 1 — Do these first (nothing else can start until these are done)

- [x] **Title locked: "Rogue Harem."** Decided 2026-08-09.
- [x] **Trademark sanity check — clear.** Checked Google and tmsearch.uspto.gov, no existing
  registered trademark or shipped game collision found.
- [ ] **Create the Steamworks account.** Go to
  [partner.steamgames.com](https://partner.steamgames.com), sign up with your Steam account,
  accept the distribution agreement.
- [ ] **Register the app and pay the fee.** In the Steamworks dashboard, register a new app,
  pay the **$100 Steam Direct fee** by card. This is recouped automatically out of your first
  $1,000 in gross sales — it's not a sunk cost, it's an advance. You now have an **App ID**
  (a number) — write it down, every later step references it.

---

## STAGE 2 — Four tracks, run all of them at the same time, starting right after Stage 1

### Track A — Art (Goku)

Produce these, in this order (each unlocks the next thing that needs it):

- [ ] Logo (transparent PNG, any size, scalable)
- [ ] Header Capsule — 920×430
- [ ] Small Capsule — 462×174
- [ ] 5+ real-gameplay screenshots — minimum 1920×1080 each, actual gameplay, not mockups
- [ ] Main Capsule — 1232×706
- [ ] Vertical Capsule — 748×896
- [ ] Library Capsule — 600×900
- [ ] Library Hero — 3840×1240
- [ ] Library Logo — 1280×1280
- [ ] Page Background — 1438×810
- [ ] Trailer (30-60s, hosted on YouTube, embedded on the store page) — do this last, it
  benefits from screenshots already being picked and from finished footage existing.

### Track B — Third-party asset & license audit (do this yourself, it's not art work)

This is the concrete version of what "check licenses" actually means. Go through it folder
by folder:

- [ ] **Audio.** Open `assets/audio/bgs/` and `assets/audio/sfx/`. Current files:
  `dungeon_ambient.wav`, `forest_ambient_day.wav`, `forest_ambient_night.wav`,
  `river_ambient.wav`, `village_ambient_day.wav`, `village_ambient_night.wav`,
  `build_complete.wav`, `combat_block.wav`, `combat_hit_light.wav`, `combat_parry.wav`,
  `combat_swipe.wav`, `door_locked.wav`, `door_open.wav`, `footstep_player.wav`,
  `footstep_player_dirt.wav`, `pickup.wav`, `player_death.wav`, `player_dodge.ogg`,
  `player_hurt.wav`, `player_jump.wav`, `player_land.wav`, `player_land_dirt.wav`,
  `player_slide.wav`, `ui_cancel.wav`, `ui_click.wav`, `ui_confirm.wav`. For each one, find
  out: did Goku record/make it himself, or was it pulled from somewhere (freesound.org, an
  itch.io SFX pack, Kenney.nl, a paid asset bundle, etc.)? Ask directly if you don't already
  know.
- [ ] **Font.** `assets/fonts/main_font.ttf` is already flagged as third-party and slated for
  replacement. Once the new font is picked, find its license page (Google Fonts and most
  itch.io fonts use the SIL Open Font License, which allows commercial use and bundling with
  attribution — but confirm per-font, don't assume).
- [ ] **Art/sprites.** Check `character_parts/`, `concubine assets/`, `buildings/`,
  `effects/`, `NPC/`, `objects/`, `tools/`, `traps/`, `UI/` for anything not drawn by Goku
  from scratch (a purchased tileset, a free asset pack, etc.).
- [ ] For every third-party item found above: locate its original source page, note the exact
  license (CC0 = free, no attribution needed; CC-BY = needs attribution; a store-bought pack
  = read its specific commercial/redistribution terms, they vary a lot).
- [ ] **Create `otto-man/otto-man/THIRD_PARTY_LICENSES.txt`** and paste into it:
  - Apache License 2.0 full text + this line: *"This game includes
    Mistral-NeMo-12B-Instruct, © Mistral AI, licensed under the Apache License, Version 2.0."*
  - MIT License full text + the copyright notice from the llama.cpp GitHub repo.
  - The chosen font's license text + attribution line.
  - One line per third-party audio/art asset found above, with its license type and source URL.
- [ ] Add `THIRD_PARTY_LICENSES.txt` to the Godot export: **Project → Export →** select your
  export preset **→ Resources tab → add it under "Export Non-Resource Files/Folders."** Do
  this now so it can't get forgotten on a future build.

### Track C — Legal paperwork (writing only, no dependencies on art)

- [ ] **Write the EULA.** Search "indie game EULA template" (itch.io and several indie-dev
  blogs publish free ones) and adapt one — swap in the title, add a line that AI-generated
  dialogue content may vary/be unpredictable, add the standard "this is a license to play,
  not a sale of the software" clause. Save it as a page or `.txt` file you can link from both
  storefronts.
- [ ] **Write the privacy statement.** Two sentences is enough:
  *"This game does not collect, transmit, or store any personal data. All AI processing
  happens locally on your device."* Save it the same way as the EULA.
- [ ] **Draft the AI-content disclosure wording**, ready to paste into Steam's survey later:
  *"NPC dialogue is generated in real time by a locally-run, open-weight language model
  (Mistral-NeMo-12B-Instruct). No player input, chat content, or personal data leaves the
  player's device — all processing happens on-device. The system is instructed to refuse
  sexual content and any content involving harm to minors. As with any AI system, we cannot
  guarantee these safeguards are impossible to circumvent."* Don't claim it's foolproof —
  state the safeguard and its limit, honestly.

### Track D — itch.io placeholder page

- [ ] Go to itch.io, create an account, click **Create new project**. Fill in the title and a
  short description, upload whatever logo/art already exists (even a placeholder is fine),
  leave visibility set to **Draft** until you're ready to actually publish it.

### Track E — Raw content capture

- [ ] Film 3-5 clips' worth of raw gameplay footage now — don't post any of it yet (there's
  no wishlist link to send people to until Stage 5). Save the raw files in a folder so
  editing in Stage 4 has material to work with.

---

## STAGE 3 — Submit the Steam store page (once Track A's minimum bar is done: logo, one capsule pair, 5 screenshots, trailer)

- [ ] In Steamworks: **Store Presence → Store Assets** — upload each image at its exact
  dimension from the Track A list above.
- [ ] **Store Presence → App Details** — write the store description (short + long) and pick
  genre tags.
- [ ] **App Admin → Legal → IARC Rating** — answer the questionnaire honestly (yes, there's
  combat blood; be specific rather than vague). It's free and self-service, and generates the
  actual PEGI/ESRB-equivalent rating instantly.
- [ ] **App Admin → Store → Content Survey** — select **"Live-Generated AI Content"** (not
  "pre-generated" — the NPC dialogue is generated live from player input, which is the
  stricter tier). Paste the disclosure wording drafted in Stage 2 Track C.
- [ ] **Same Content Survey section** — separately fill the **Mature Content / Adult-Only
  Sexual Content** questionnaire. This is independent of the AI-content one above; both are
  required, don't stop after just one.
- [ ] Link the EULA and privacy statement (Track C) in the relevant store page fields.
- [ ] Click **Submit for Review.** First-time review typically takes 2+ weeks — nothing more
  to do here, that wait time is exactly what Stage 4 is for.

---

## STAGE 4 — While the page is in review (parallel, fills the 2+ week wait)

- [ ] **Set up Discord.** Create the server, build these channels: `#welcome-and-rules`,
  `#announcements`, `#general-chat`, `#screenshots-and-fanart`, `#suggestions`,
  `#bug-reports`, `#dev-log`, and optionally one age-gated channel (Discord has a built-in
  age-gate/NSFW channel setting) if you want a space for more explicit content/discussion.
  Do **not** post the invite link publicly yet.
- [ ] **Register matching handles** on X/Twitter, TikTok, YouTube, Instagram, Reddit — same
  title, now that it's locked from Stage 1.
- [ ] **Edit 2-3 finished short-form clips** from Stage 2 Track E's raw footage. Structure:
  hook/comment → show it happening in-game → payoff/funny result → end card with the game
  name. Save them in a "ready to post" folder — don't post yet.
- [ ] **Build a press kit.** Use a free tool like [presskit()](https://dopresskit.com) by
  Rami Ismail, or just a simple folder/zip: logo, the 5 screenshots, a one-paragraph pitch,
  your contact email, and the trailer link.
- [ ] **Decide on a Turkish store page.** The game is already fully localized in Turkish —
  translate the store description/short description into Turkish too, then in Steamworks go
  to **Store Presence → Localization** and add Turkish as a supported store language. This
  taps Steam's language-based discovery boost and an audience with obvious cultural affinity
  for an Ottoman-themed game, at near-zero extra cost since the translation work is mostly
  already done for the game itself.

---

## STAGE 5 — Page goes live (Valve approves it)

This is the actual pivot point — the first moment a real wishlist link exists to send anyone
to. Nothing gets published before this.

- [ ] Confirm the store page is public: `store.steampowered.com/app/<your App ID>` loads for
  a logged-out browser.
- [ ] Post the Discord invite link in your other social bios/posts.
- [ ] Publish the Stage 4 content backlog — every post's call-to-action is now the real
  wishlist link, not a placeholder.
- [ ] Update the itch.io page's call-to-action text to point at the Steam wishlist URL as the
  primary destination.

---

## STAGE 6 — Ongoing content cadence (starts at Stage 5, continues until launch)

- [ ] Keep two separate content styles going:
  - **Safe clips** (TikTok, YouTube Shorts, Instagram Reels) — no spoken/written title or
    audio, algorithm-friendly, casual gameplay moments.
  - **Expressive posts** (X/Twitter, Discord, the Steam page itself) — full title, character
    art, more direct promotion.
- [ ] After every post, check **wishlist count and rate of new adds**, not views or likes —
  that's the number that actually predicts revenue, and it's what tells you whether a clip
  is working or just noisy.

---

## STAGE 7 — Demo / Steam Next Fest decision

- [ ] Check the current Next Fest window: **October 19-26, 2026** — registration closes
  **August 31, 2026**, demo build due **September 21, 2026**. Compare that against Goku's
  real art timeline from Stage 2 Track A.
- [ ] If the art/demo timeline looks tight against that window, **skip it and target the next
  edition (February 2027)** instead — a rushed, buggy demo during a Next Fest slot burns
  a mostly one-shot exposure opportunity; better to skip a cycle than waste it.
- [ ] Once a demo exists, keep it live on the store page permanently (not just during the
  festival) — free ongoing discovery surface.

---

## STAGE 8 — Final 4-6 weeks before launch

- [ ] **Post a dedicated release-date-announcement trailer/clip**, separate from the original
  reveal trailer. This reliably produces a second wishlist spike distinct from the first
  announcement.
- [ ] **Send review copies to streamers/press** using the Stage 4 press kit — pick
  small/mid-size creators who cover similar genres (roguelike, village-sim, narrative), time
  it so coverage lands close to launch rather than scattered weeks early.
- [ ] **Increase posting frequency** in the final 1-2 weeks specifically — wishlist velocity
  right before launch is what Steam's launch-week discovery algorithm weighs most heavily.
- [ ] Add a short **"planned updates" section** to the store page description — buyers
  convert better when they see committed post-launch support, not just a finished box.

---

## STAGE 9 — Launch day

- [ ] Time the trailer publish, any press embargo lift, and the community/social push to all
  land the same day — concentrated attention beats the same posts spread across a week.
- [ ] **Check and respond to reviews every few hours for the first 48 hours.** A fixable
  complaint answered fast can stop a negative review from ever being posted, and this window
  disproportionately sets the review-score momentum Steam's algorithm carries forward.

---

## STAGE 10 — After launch (revenue doesn't stop at day one)

- [ ] Keep responding to reviews and patching fixable complaints — review score/count keep
  compounding into future discovery long after launch week.
- [ ] Plan participation in Steam's seasonal sales (Summer/Winter/Autumn/Spring) rather than
  missing them by default — these are major recurring visibility + conversion events.
- [ ] Ship meaningful post-launch content updates — each one re-surfaces the game in Steam's
  "recently updated" discovery surface and re-engages people who already wishlisted/own it.
- [ ] Revisit regional pricing and whether to add more store-page languages, based on actual
  post-launch sales data by region, instead of leaving pricing/localization untouched forever.

---

## Order-of-operations reminders

- Film/edit content anytime (Stage 2) — **publish** only after Stage 5 (the page is live and
  a real wishlist link exists).
- Don't register public handles before the title is locked (Stage 1) — avoids squatting a
  name that might still change.
- Don't publicize the Discord invite before Stage 5 — there's no live CTA to gather people
  around yet.
- Don't submit the Steam page (Stage 3) before both the IARC questionnaire and both content
  surveys are filled — Valve won't approve it otherwise.
- The 2+ week Steam review wait (Stage 3 → 5) is not dead time — Stage 4 is built specifically
  to fill it.
