# Frij — V3 Vision Doc (v7)

Running file of bigger ideas. Updated as we go.

> **v7 additions:** More modes (occasions vs modifiers), and Use It Up — both
> at the bottom.
>
> **v6 addition:** Meals ↔ Desserts mode switch (bottom).
>
> **v5 additions:** Calorie Tracking & Scanning, Ingredient Sourcing / Store
> Finder, and Context-Aware Notifications (all at the bottom, all folded into
> the running list). Everything above them is unchanged from v4.

---

## The thesis underneath everything

Frij wins when it stops being a tool and becomes:
1. **The persistent state of your kitchen** (pantry, quantities, history)
2. **A sense of who you are** (diet, household, cuisine, taste)
3. **A source of craving and inspiration** — not just answering "what should
   I cook" but planting the question in the first place

Competitive frame: anyone can ask ChatGPT what to cook. Frij wins on the
**second visit**, because by then it knows you. ChatGPT has to be re-told
everything. Frij doesn't.

---

## V3 — Voice Ingredient Capture ⭐

> The user taps a mic button and just *talks*. "I got chicken, leftover
> rice, soy sauce, half an onion, a bunch of cilantro, oh and some lime."
> Frij parses the audio, extracts the ingredients, adds them to the pantry.
> No typing. No decision-per-item. The pace at which you'd inventory your
> own kitchen out loud.

### Why this is huge

Typing each ingredient is the **biggest friction point in Frij right now**.
Scan is fast but only catches what's visible. Manual add forces the user to
type → wait for validation → type the next thing → wait. For a stocked
kitchen of 20 items, that's 20 round trips.

Voice collapses all of that into one ~15-second interaction. The user just
*thinks out loud* and Frij captures it.

### What it would actually look like

1. **Big mic button** somewhere in the pantry view ("press to talk").
2. **User talks naturally:** "Eggs, milk, butter, some leftover tofu, half
   a jar of kimchi, sriracha, scallions..."
3. **Whisper transcribes** the audio (OpenAI has a Whisper API, ~0.6¢/min,
   cheap).
4. **A second model pass** parses the transcript into a clean ingredient
   list, runs each through validation, adds to pantry. The user sees a
   "here's what I heard, tap to remove anything wrong" confirmation step.
5. **Descriptive mode** — user can also say things like "the chicken's been
   in there a couple days," "I'm running low on olive oil." These metadata
   bits get attached to pantry items and feed back into the quantity-tracking
   feature later. Same architecture as the manual "running low" toggle, but
   captured passively from natural speech.

### Why it's the unlock

It's the closest thing to telepathy. The user thinks "what's in my fridge"
and Frij just... knows. No screens, no taps. That's category-different from
every other recipe app, which all assume the user is willing to type.

### Why it's V3, not V1

- Whisper API integration is real work (audio recording, upload, parsing)
- Parsing free-form speech into structured ingredients requires careful
  prompting (the "I got, uh, like, some chicken" speech patterns are messy)
- Confirmation UX needs to be quick and forgiving
- Real users will say things in 100 different ways — needs testing

But the stepping stones are easy:
- Add a mic button that just opens iOS dictation into the existing text
  field. That gets 60% of the value with ~zero engineering.
- Build the full custom flow once we know users want it.

---

## V3 — Pinterest-Style Inspiration Board ⭐

> NOT gamification. NOT streaks. A whole page that's just **beautiful meals
> to lust after.** Endless scroll, gorgeous photos. The user scrolls until
> something stops them — "oh my god, hummus with lamb" — taps it, sees the
> recipe. Maybe they go buy the ingredients. Maybe it goes in their saved
> board.

The point: the user came to Frij with *no intent* and left with a *craving*.
That's the opposite of "I need to cook tonight." That's **Frij gave me an
idea I didn't have.**

### Why this is its own category

Other Frij features answer "I'm hungry, what should I cook?" The board
answers a different question: "What should I want to cook?" That's not
utility — that's inspiration. Different muscle entirely.

Other recipe apps have grids of recipes too — but they're searchable lists.
Pinterest works because it's *endless scroll of things that look good.*
You're not searching; you're being seduced.

### What it would actually look like

1. **A new tab** (the bookmark icon could become this, or a new one)
2. **Vertical infinite scroll of meal photos** — full-bleed, high quality,
   varied cuisines, varied vibes (quick weeknight, weekend project, comfort
   food, healthy, fancy date night)
3. **Personalized over time** — surfaces cuisines / styles the user has
   shown interest in via favorites + cuisine setting + cooked history
4. **Tap → recipe detail.** From there:
   - "I'll cook this" → checks pantry, shows what they have vs need, can
     start cooking
   - "Save for later" → goes into a saved board (Pinterest-style boards
     within the board)
   - "Not for me" → trains the relevance model (more of this kind / less of
     that kind)
5. **Boards as collections** — user can curate their own ("date night,"
   "Sunday cooking," "things I want to try"). Public/shareable boards are a
   social hook for later.

### Why it depends on a lot

The board can't ship without:
1. **Image generation** (V2 — already planned). The whole point is the
   photos. Without consistent, beautiful imagery the board is just a list.
2. **A shared recipe catalog** that exists across users. Right now recipes
   are generated per-user on demand. The board needs a *pool* of recipes
   that grows over time — every dish anyone cooks becomes a candidate.
3. **Relevance ranking.** Not just "newest" — needs to learn what each user
   responds to. Real recommendation system, even if simple at first.

This is why it's V3, not V2. It depends on accounts + image gen + a catalog.
But it's the *end goal* — the visual layer that turns Frij from "tool that
sees my fridge" into "app I open when I'm bored, like Instagram for food."

### Monetization idea (parked 2026-07-24)

The board is a natural **paid unlock** — and worth trying as a *one-time
payment* rather than a subscription, since it's a mode you unlock, not a
service you consume monthly (one-time can beat recurring for a cooking app and
dodges subscription fatigue). Keep the fridge-first generator free (the wedge);
sell the aspirational board. Lean: keep taste personalization ("Because you…")
free too — it's the hook that proves Frij gets you. A/B one-time vs. sub later.

### Connection to other features

- **Cuisine personalization** feeds the board (lead with Persian dishes for
  Persian users)
- **Image generation** is the engine (no images, no board)
- **Social sharing** comes naturally (boards are inherently shareable)
- **Favorites** feeds the saved-board feature
- **Cooked history** trains the relevance model

The board is the surface that ties most of the other V3 features together.

---

## V3 — Cuisine Personalization ⭐

> Frij doesn't just generate "a recipe." It generates recipes from cuisines
> that *mean something to you*. A Brazilian user gets farofa with their
> steak. A Persian user gets tahdig. A Vietnamese user gets phở. Not
> "American dinner with international flavors" — their actual food, the
> food their family makes.

[unchanged from v3]

The emotional layer: Diet says "I don't eat meat" (information). Cuisine
says "my mom made this every Friday" (identity).

Stepping stones:
- Add cuisine field to ProfileView (1-line addition)
- Update recipe prompt to weight cuisine heavily (1-line addition)
- Test with one specific cuisine first (Persian, since Gabe can validate)
- Then open it up

Possible Frij V1.5 launch story: "Frij made me ghormeh sabzi from what's in
my fridge" — way more compelling demo than generic chicken pasta.

---

## V2 — "Feeling Adventurous?" nudge (idea, 2026-07-24)

> A one-tap escape hatch from the fridge, offered only when it helps —
> "Feeling adventurous? Dishes worth a quick shop." Tap it and Frij suggests
> things matched to your *taste*, not your current pantry, allowing a small
> shopping list.

### Why a nudge, not a setting

We debated a mode toggle — "cook what I have" vs. "what I'd love." Rejected it:
a permanent switch taxes every user on every visit, and the 6pm "feed me now"
moment should stay one-tap. The two are different jobs at different moments,
not two dials on one button. So the fridge-first generator stays the default
(it's Frij's whole identity), and aspiration shows up *contextually*.

### What it looks like

- Appears only when it's actually useful: the pantry is thin, the results feel
  repetitive, or the user just cleared their picks. Disappears otherwise.
- One tap → recipes driven by the **taste profile** (the "Because you…" layer
  we already built), with the pantry constraint relaxed — a couple of "you'll
  need" items are fine, the point is the *craving*, not the inventory.
- Cheap to build: it's the existing recipe call with the pantry constraint
  loosened and taste weighted up. No new surface, no accounts, no image gen.

### How it relates to the board

This is the **lightweight, near-term taste of aspiration** — the full payoff
is the Pinterest board (endless-scroll discovery). The nudge validates whether
people even *want* aspiration inside Frij before we build the expensive board.
If the nudge gets tapped a lot, that's the signal the board is worth it.

---

## V3 — The Real Pantry: continuous quantity tracking

[unchanged from v3]

Frij knows you have a *bottle* of olive oil, not just "olive oil." Tracks
usage across cooked meals. Surfaces "you're running low on X." The
"check-in when unsure" loop is the moat.

Stepping stones:
- "Last seen" surfacing
- Manual "running low" toggle
- "I'm out of this" button on recipes
- Recipe usage hints (model outputs quantity estimates)

Note: voice ingredient capture (above) feeds this naturally. Users naturally
say "I'm low on X" when listing their pantry out loud.

---

## V3 — Gamification (positive only, separate from Pinterest)

This is its own thing, NOT the Pinterest board.

Streaks, badges, collections. **Celebration only — no guilt.**
- Cooking streaks
- First-time badges ("first miso," "first farofa")
- Pantry health score (using what you have)
- "Tried 5 cuisines" / explorer badges

Duolingo-style guilt notifications are toxic in a food app. Lean into
celebration of what they did, never pressure about what they didn't.

---

## V3 — Light Social

NOT a feed. NOT comments. Just: share a recipe with a friend (URL link →
opens in Frij or web preview). Cheap to build, strong growth lever.

Could expand to shareable Pinterest boards once the board exists.

---

## V3 — Household Mode

One pantry, multiple users, merged dietary prefs AND merged cuisines (Persian
+ Italian household is its own category). Needs accounts + invite flow.

---

## V3 — Meal Image Generation

The engine that powers the Pinterest board. Consistent art style across all
recipes. Generated once across all users, cached. ~5-10¢ per new recipe;
cached hits free.

Pick one style and commit:
- Overhead, matte black plate, soft daylight (moody / NYT)
- Casual, wooden table, warm tones (homey / Bon Appetit)
- Bright, white background, minimal (clean / Apple-y)

Probably the homey style works best across cuisines.

---

## Operational principle (rewritten 2026-07-25)

The original version said "nothing gets built before TestFlight." Reality:
1.0 went straight to App Store review, and the review wait was spent building
— which was right, because that work (voice capture, cancel, personalization)
is what made the app worth putting in front of strangers. The principle isn't
retired; it's updated to what it was always really about:

**Pre-users, building was free because there was nothing to learn from. From
the moment real users exist, real usage outranks speculation.**

1. Once strangers have the app, a new feature needs either a **user signal**
   (watched usage, unprompted asks) or a **load-bearing reason** — scan
   accuracy is the standing example: it's the make-or-break of the core
   promise and needs no vote.
2. Waiting-on-review time may be spent building — but only what makes the
   next release more worth reviewing, never a new surface nobody asked for.
3. One week of ten real users reorders this roadmap better than any amount
   of brainstorming. Ship, watch, then build.

---

## Growth notes (Gemini brainstorm, 2026-07-25)

- **Positioning line:** "Frij is the 10-second cure for decision fatigue in
  your kitchen — snap what you have, get three meals you'll actually want to
  cook tonight."
- **Wedge audience:** urban professionals + students, 21–30. High TikTok use,
  6pm decision fatigue, takeout-spend anxiety, small fridges.
- **Channels (near-zero budget):** micro-creator "fridge audit" reels
  (unscripted, messy real fridges), founder-led daily scans of submitted
  fridges, subreddit launch posts (r/eatcheapandhealthy etc.) framed as
  solo-dev anti-bloat project.
- **Share loop ⭐ — "Fridge Roast":** after a scan, offer a 1-tap shareable
  story card — "Frij rated my fridge 4/10 on diversity but still found 3
  dinners." Playful self-deprecating stats get shared; recipe cards don't.
  Could extend to a weekly "Rescue Score" (money/food saved).
- **Vs. competitors, one line each:** ChatGPT = typing homework while hungry;
  SuperCook = 50 inventory checkboxes. Frij = one photo, straight to dinner.
- **Filter to apply to CORE-FLOW features only:** "does this reduce the time
  between opening the fridge and starting to cook?" (Deliberately NOT applied
  to the discovery layer — the board/import serve a different moment.)
- **Standing risk to respect:** scan quality is load-bearing — two bad
  recommendation sets = uninstall. Recognition accuracy > every new feature.

---

## Running list

**Identity / personalization:**
- ☐ **Voice ingredient capture** ⭐ (the friction killer)
- ☐ **Cuisine personalization** ⭐ (the "it sees me" feature)
- ☐ **Pantry-aware sides** — "Pair it with" suggestions badged/filtered by
  what's in (or expiring in) the fridge: "use up your bell peppers → roast
  them as a side." Turns a generic widget into anti-waste. Also: replace the
  tiny "rotate" text with a swipeable row. (Gemini audit, 2026-07-25)

**The pantry as memory:**
- ☐ **Real pantry quantity tracking** (the moat)
- ☐ Last-seen surfacing (stepping stone)
- ☐ Manual "running low" toggle (stepping stone)
- ☐ "I'm out of this" button on recipes (stepping stone)
- ☐ Recipe usage hints (stepping stone)

**Inspiration / discovery:**
- ☐ **Pinterest board** ⭐ (the dopamine layer)
- ☐ **TikTok / social video import** ⭐ (the catcher's mitt for food inspiration)
- ☐ Meal image generation + cache (the engine)
- ☐ User-curated boards / collections
- ☐ URL paste / recipe link import (stepping stone for TikTok import)

**Modes:** *(new in v6)*
- ☑ **Meals ↔ Desserts switch** (shipped — single Desserts chip on the pantry)
- ☐ **Snack** and **Breakfast** occasions *(v7)*
- ☐ Drinks / smoothies occasion *(v7)*
- ☐ Hosting / appetizers occasion *(v7)*
- ☐ Modifiers — quick, batch-cook, no-cook *(v7, a separate control)*
- ☐ Move the mode picker into the cook button once there are 3+ *(v7)*

**Anti-waste:** *(new in v7)*
- ☐ **Use It Up** ⭐ (one tap, cooks from what's about to spoil)

**Health & logistics:** *(new in v5)*
- ☐ **Calorie tracking & scanning** (opt-in health mode)
- ☐ **Ingredient store finder** (maps + stock confidence)
- ☐ **Context-aware notifications** (saved meals + grocery pickup on your route)

**Scan polish:**
- ☐ **Spatial detection — dots pinned to real items** (UI built; needs crop-offset fix or Gemini swap)

**Engagement:**
- ☐ Gamification (streaks, badges — celebration only, no guilt)
- ☐ Light social sharing

**Foundation:**
- ☐ Accounts (Sign in with Apple + Supabase)
- ☐ Household mode

---

## V3 — TikTok / Social Video Import ⭐

> User's scrolling TikTok, sees a beautiful pasta video. Hits Share → Frij.
> The app receives the video, understands what dish it is, generates a
> clean recipe, drops it into the user's saved meals. Next time they open
> Frij: "here's that pasta you saved yesterday — wanna cook it?"

### Why this is genuinely big

Right now, food TikToks die. You watch one, you go "damn that looks good,"
and 30 minutes later you've forgotten the dish, you don't remember the
creator's name, you can't find the video again, the inspiration is gone.

TikTok is a *great* discovery surface but a *terrible* retention surface
for cooking. The entire ecosystem of food creators is generating a tidal
wave of inspiration that goes nowhere.

**If Frij becomes the catcher's mitt for that tidal wave, it's not a feature
— it's a moat against TikTok itself.** TikTok shows the dish, Frij makes
it real. Different jobs, both essential, Frij wins because it's the one
that actually feeds you.

### What it would actually look like

1. **iOS Share Extension.** When user hits "Share" on a TikTok (or Instagram
   Reel, or YouTube Short — same architecture), Frij appears in the share
   sheet alongside iMessage, etc.
2. **User taps Frij.** Quick "saving this..." moment.
3. **Backend pipeline:**
   - Receives the video URL or video file
   - Pulls metadata: caption, audio transcript, on-screen text, creator
   - Uses a vision/audio model to understand what dish is being made
   - Generates a clean structured recipe (name, ingredients, steps) — same
     format as Frij's regular recipes
   - Returns it to the app
4. **Frij confirms:** "Saved 'Tomato pasta with burrata.' Tap to view."
5. **User sees the recipe** in their saved meals, can cook from it later,
   can check it against their pantry, etc.

### What makes this hard

- **Video understanding** is genuinely difficult. Models can analyze frames
  but cooking videos are fast, dishes get assembled out of order, and
  caption text often disagrees with what's actually on screen.
- **TikTok's API access is restrictive** — might require scraping or working
  with shared URLs only (which works fine for the user's flow).
- **Quality bar is brutal.** If Frij imports a TikTok and the recipe is
  wrong, the user trusts the app less. Has to be *very* accurate or it
  poisons the well.
- **Cost.** Video understanding is expensive (vision model on multiple
  frames + audio transcription). Per-import cost is probably 10-30¢, not
  fractions of a cent.

### Why it's V3+ (the "way up there" timeframe)

This requires:
- Video understanding pipeline (real ML work)
- iOS share extension (real iOS work)
- Probably accounts (recipes saved server-side, not locally)
- High accuracy on a hard problem (might require fine-tuning)
- Budget for per-import API costs

But the *concept* is sound and worth holding onto. It's the move that takes
Frij from "useful kitchen app" to "the bridge between social media food and
your actual dinner." That's a real cultural position.

### Competitor proof point (2026-07-25): ReciMe

ReciMe (recime.app) already ships this capture flow — save recipes from IG
reels/TikToks/photos via the share sheet into one organized place. Takeaway:
the share-sheet path is validated and people pay for it. Differentiation is
NOT the filing cabinet (they own that); it's the pantry: "that reel you saved?
You have 7 of its 9 ingredients — cook it tonight." Import + fridge is the
version worth building. V1 (paste-a-link, caption→recipe) SHIPPED 2026-07-25;
share extension deferred to post-users.

Research findings (public sources, full cites in session notes):
- **Their pipeline:** share extension + paste-URL; extraction falls back
  caption → video AUDIO transcript → the creator's linked source site. No
  visual/frame analysis claimed. They admit IG login walls beat them too
  ("ReciMe can only see what's public") — same wall we hit; nobody solves it.
- **Their documented failures (our bar to beat later):** video-only recipes
  with no caption, recipes posted in COMMENTS (super common on IG),
  multi-recipe posts, screenshot OCR misses.
- **Business:** ~$2M raised (incl. Marissa Mayer), Melbourne→NYC, claims 10M
  users, 4.8★/264K ratings. Sub-only $40–60/yr; free tier caps the CORE
  promise at 5 imports — reviewers call it bait-and-switch (pricing lesson).
- **The gap:** zero inventory awareness, no discovery, no "what can I make
  tonight." Everything Frij is, they aren't. Import is the only overlap.
- **Later upgrades to leapfrog their importer:** audio-transcript tier,
  comments parsing, share extension.

### Dead end to avoid (settled 2026-07-24)

The tempting version — "connect your Instagram/TikTok and we'll read your
*saved* collection to cook from" — is **not buildable.** Neither platform
exposes a user's saved/favorited posts through any official API (Instagram
has none for saves at all; TikTok's API only reaches a user's own uploads).
Scraping violates ToS and gets the app pulled. So the capture mechanism is
**always the Share Sheet / a pasted link**, never account linking. Same magic
("the food you saved but never made → dinner tonight"), just entered through
the door iOS actually gives us. Don't re-litigate the account-connect route.

### Stepping stones

Cheaper versions of the same idea that ship sooner:
- **URL paste:** user pastes a TikTok URL into Frij, backend fetches metadata
  and caption, generates a "best guess" recipe. No video parsing, just text.
  Way cheaper, ships faster, validates if anyone cares.
- **Recipe link import:** same flow but for written recipes (NYT Cooking,
  Serious Eats blog posts). Easier to parse, no video pipeline. Could ship
  with V2.
- **Manual capture:** user sees a TikTok, taps "Save dish idea" in Frij,
  types or voice-records what the dish was. No social-media integration —
  just a way to catch the idea before it escapes.

### Connection to the rest of the vision

- **Pinterest board:** imported TikTok recipes feed the board. Now the board
  has both AI-generated meals AND real meals from real creators. Richer.
- **Voice capture:** ties together. User watches TikTok, says "save that
  pasta thing." Frij captures the dish via voice + video together.
- **Social sharing:** the loop closes. Imports come in, shares go out.

---

## V3 — Spatial Detection: dots pinned to the actual items

> After scanning, the "We found" labels don't float in random positions —
> each one is pinned to where the item *actually is* in the photo. A little
> dot sits on the olive oil bottle, the salmon, the bread. The user looks at
> their own fridge photo and sees Frij has visually understood it. It's the
> difference between "the app made a list" and "the app can SEE."

### Why it matters

It's the moment the magic becomes visible. A list of ingredients is useful
but invisible — the user has to trust that Frij looked carefully. Dots
pinned to the real objects *prove* it looked. It's a small thing that makes
the scan feel intelligent rather than like a black box. Pure polish, but the
kind of polish that makes people screenshot the app and show their friends.

### What we already built (and why it's parked)

This got most of the way to working on June 9. The full UI is **done and in
the codebase** — floating glass labels with dots, spring-in animation,
positioning logic in ScanFlowCoordinator. The backend was updated to return
bounding boxes too. So this is not a from-scratch feature; it's a
finish-the-last-10% feature.

What's built:
- Backend (`scan.js`): prompt asks gpt-4o for a `box {x, y, w, h}` per item
  (0–1 fractions), parsed + sanitized, returned in the scan response. Live.
- Models (`FrijModels.swift`): `BoundingBox` struct + optional `box` field on
  `DetectedItem`. Done.
- iOS (`ScanFlowCoordinator.swift`): `labelPosition` uses the box center when
  present, scattered fallback when not. Done.

### What we learned from real testing (the important part)

We tested gpt-4o's box quality on a real fridge photo. Results:
- **3 of 4 boxes were roughly right** (olive oil, sugar, salmon landed on or
  near the correct objects).
- **1 was clearly wrong** (bread placed far-right near the air fryer, where
  no bread was).
- So gpt-4o's spatial grounding is **decent but not reliable** — good enough
  to feel intentional, not good enough to feel precise.

**The likely rendering bug (not fully fixed):** the photo uses `.scaledToFill`,
which crops to fill the screen. The boxes are relative to the *original*
image dimensions. So even correct coordinates render in the wrong on-screen
spot, because the crop offset isn't accounted for. The dots looked more wrong
than the raw coordinates actually were. **Two fixes to try when resuming:**
1. Switch the photo to `.scaledToFit` (boxes map directly, but letterbox bars
   appear) — quick test to confirm the crop is the culprit.
2. Do the proper crop-offset math to keep `.scaledToFill` and place dots
   correctly. This is the real fix.

### Two paths when we come back to it

1. **Fix the rendering + keep gpt-4o.** If the scaledToFill math is the real
   problem (likely), gpt-4o's boxes might be good enough once placed
   correctly. Cheapest path — no model change, the UI's already built.
2. **Switch the vision model to Gemini.** Google's Gemini is genuinely strong
   at bounding-box grounding (it's a documented strength) and returns clean
   coordinates. If we want *precise* dots, this is the move. Backend-only
   change: swap the OpenAI call in scan.js for Gemini, needs a Google AI key.
   The iOS side is already done and would just work.

### Why it's parked, not dropped

The core scan→dinner loop works and matters more. Dots-on-items is polish.
But it's *most of the way built* and we know exactly what's left (the crop
math) and the fallback plan (Gemini). Worth finishing once the fundamentals
are validated with real users — and it's a strong "wow" demo moment when it
lands.

### Stepping stone

The current scattered-dot version (no real positions) could ship as-is — it
already looks intentional even without accurate placement. Or hide the dots
entirely and keep just the clean "We found" panel (which is already good),
then bring dots back once the positioning is solid.

---

## V3 — Use It Up *(new in v7)* ⭐

> One tap that cooks from the food about to go bad. Not a new mode, not a new
> screen — a small "Cook these" action sitting next to the USE SOON band.

### Why this is the strongest small idea in the doc

- It **is the mission.** No food goes to waste is the reason Frij exists, and
  nothing else in the app acts on it directly.
- **The data already exists** — `freshnessWarning` and the USE SOON band ship
  today.
- **The machinery already exists** — multi-select plus "Cook with these N" is
  built, so this is one tap that selects the USE SOON chips and fires it.
- **No competitor can copy it.** Other recipe apps don't know what's dying in
  *your* fridge. Neither does ChatGPT. This is only possible because Frij holds
  the persistent state of your kitchen — the thesis at the top of this doc,
  cashed in.

### What it would look like

A quiet "Cook these" next to the USE SOON header. Tap it and the band's chips
are selected and the cook button fires with just those. Roughly an hour of work
given what's already in place.

### Watch

Cooking *only* from near-spoiled items can produce a thin recipe (three sad
vegetables). It should probably select the USE SOON items **plus** whatever
staples make them into a real dish, rather than passing the expiring items
alone.

---

## V3 — More Modes: occasions vs modifiers *(new in v7)*

> Dinner and dessert shouldn't be the only two things Frij can make. But the
> additions split into two kinds that must not share one control.

### The distinction that matters

- **Occasions** — dinner, breakfast, snack, dessert, drinks, hosting. Mutually
  exclusive. "Which meal is this?"
- **Modifiers** — quick, batch-cook, no-cook, use-it-up. These *qualify* an
  occasion rather than replacing it.

A menu reading *Dinners / Snacks / Quick / Use it up* is incoherent: "quick"
isn't an alternative to dinner, it's an adjective on it. Occasions belong in
one picker; modifiers need their own control (or none — they can be phrased
into the existing prompt).

### Occasions worth adding

- **Snack** ⭐ — the strongest addition. A real, distinct ask ("something small,
  no cooking") with output nothing like dinner.
- **Breakfast** ⭐ — genuinely different food, genuinely different occasion.
- **Drinks / smoothies** — cheap, and it finally uses the fruit, yogurt and milk
  that no savoury recipe touches.
- **Hosting / appetizers** — occasional but high-intent.
- **Lunch — skip it.** It overlaps dinner almost entirely; the model would
  return the same dishes under a different label.

### Modifiers worth adding (later, separate control)

- **Quick / 15-minute** — probably the most universally wanted item in this
  whole document. Everyone is tired on a weeknight.
- **Batch / meal prep** — "cook once, eat four times." Pairs with the calorie
  tracking idea.
- **No-cook** — hot day, no stove, can't be bothered.

### The UI consequence (important)

The single Desserts chip that shipped works *only* because the choice is
binary: dinner is home, dessert is the one detour. Add snack and breakfast and
that pattern collapses into a row of competing chips — the exact crowding the
chip was introduced to fix.

At three or more modes, move the picker **into the cook button**: "Get 3
**dinners ▾** from this", where the mode word opens a small menu. The button
already states the mode, so this adds no new UI at all and scales to any number
of occasions. The chip disappears.

Backend-side each new occasion is nearly free — `mode` already exists, so it's
one more prompt variant per occasion.

---

## V3 — Meals ↔ Desserts Mode Switch *(new in v6)*

> One switch: "dinner, or something sweet?" Frij flips from dinners to desserts
> built from the same pantry. Same scan, same fridge, completely different
> output. And the dessert side gets its own colour — the whole app shifts shade
> when you flip it, so the mode is felt, not just read.

### Why it's worth doing

It roughly doubles what Frij can answer without doubling the UI — one toggle.
"I have eggs, butter, sugar, flour — what can I bake?" is a real and frequent
question the app currently cannot touch at all. And baking is *more* ingredient-
constrained than savoury cooking, which plays directly to Frij's strength: it
already knows exactly what's in the kitchen.

It's also a different *occasion*. Dinner is obligation; dessert is indulgence.
Catching the second craving is a genuinely separate reason to open the app.

### What it would look like

1. A toggle — either in settings or, better, right next to the cook button:
   **Dinners / Desserts.**
2. Same scan, same pantry. The prompt swaps to dessert generation.
3. The response format is identical (name, cookTime, uses, needs, steps), so
   every existing screen works with zero changes.
4. **Colour shift on the dessert side** — flipping the switch re-tints the
   accent (the warm orange moves toward a berry/pink or cocoa tone). It makes
   the mode obvious at a glance and makes the switch feel good to flip, which
   is half the reason anyone discovers a feature at all. Keep it to the accent;
   don't restyle the whole app.

### Why it's cheap

Same architecture as the cuisine lean: a `mode` field on the request plus a
second prompt variant on the backend; one toggle and one body field on iOS. No
new screens, no new data model, no new tab. Minimalism-safe.

### What to watch

- **Baking needs precision.** Quantities matter far more than in savoury
  cooking — a dessert recipe with vague amounts is much less useful. The model
  probably needs to output real measurements in dessert mode.
- **The assumed-staples list is savoury-biased.** Dessert mode wants its own
  ("flour, sugar, butter, eggs" rather than "salt, pepper, cooking oil").
- **The image catalog is all savoury** — same conflict the cuisine lean hit.
  Dessert names won't be in it, so photos generate fresh at first.
- Don't let it clutter the core flow. One switch, invisible to anyone who
  never touches it.

### Stepping stone

Ship it as a plain toggle that swaps the prompt and re-tints the accent. If
people actually use it, then invest in measurements and dessert-specific
staples.

---

## V3 — Calorie Tracking & Scanning *(new in v5)*

> A health-focused mode. The user scans (or logs) what they eat and Frij
> tracks it — building a running daily calorie + macro total. "You've had
> 1,850 calories today." Set goals ("hit 2,200 with 180g protein"), and Frij
> builds meal plans *from your pantry* that move you toward them.

### Who it's for

The health / fitness crowd — people cutting or bulking, fitness influencers,
anyone staying on top of what they eat. It's a huge, proven category
(MyFitnessPal and friends), and Frij has an angle none of them have: it
already knows what's in your kitchen, so it can plan meals that hit your
macros *from what you actually have.*

### What it would actually look like

1. A **calorie / macro scanner** — point at a plate or a package, Frij
   estimates calories + macros and logs them to today's total.
2. **Manual "I ate this"** logging as a fallback (tap a recipe → log it).
3. A **daily running tally**, editable ("no, I didn't actually eat that").
4. **Goals in settings** — target calories / protein, cutting vs bulking.
5. **Meal plans** generated from the pantry that move the user toward the goal.

### Why it's a MODE, not the default

Most Frij users don't want a calorie counter in their face — it would clutter
the core "what should I cook" loop. This has to be an **opt-in mode** for the
people who want it, and completely invisible to everyone else. The minimalism
rule holds: never make the whole app about calories.

### What makes it hard

- Calorie estimation from a photo is genuinely imprecise (portion size, hidden
  oils and sauces). Expect a "best estimate, editable" bar, never fake
  precision.
- Macro tracking + goal math is a real feature surface.
- Risk of turning a joyful food app into a guilt machine — same trap as
  gamification. Must stay celebratory / neutral, never shaming.

### Stepping stones

- Estimate a cooked recipe's rough calories (the model already outputs
  ingredients; adding a calorie estimate is a cheap prompt change).
- A simple daily total before any scanning.
- Full photo-scan-to-calories later.

---

## V3 — Ingredient Sourcing / Store Finder *(new in v5)*

> The user wants to make something but is missing a niche ingredient. Frij
> doesn't just say "you need gochujang" — it says "here's where to get it:
> H Mart, 25 min away, likely in stock." Maps + a stock-confidence read, so a
> missing ingredient becomes a solvable errand instead of a dead end.

### Why it matters

A missing ingredient is exactly where cooking intent dies. "I'd make this but
I don't have X" → nothing gets cooked. If Frij can point the user to a real
store that stocks the niche item, it closes the gap between craving and
cooking — especially for adventurous / foodie users chasing a specific cuisine.

### What it would actually look like

1. On a recipe's "you'll need" list, a missing niche item gets a **"find it
   near me"** action.
2. Frij queries a maps / places service (Google Maps, Apple Maps, or a places
   API) for stores likely to carry it.
3. Results show **distance + a confidence level** — "H Mart · 25 min · likely
   in stock" vs "corner store · 5 min · low confidence."
4. Tap → directions.

### What makes it hard

- Real-time stock data mostly doesn't exist — confidence has to be *inferred*
  from store type ("a Persian grocery probably has dried limes"), not real
  inventory. Be honest about confidence; never fake certainty.
- Maps / places API integration and cost.
- Location permission is privacy-sensitive — ask only at the moment it's used.

### Stepping stones

- Just **categorize** the missing item ("this is an Asian-grocery item") with
  no maps at all — already useful on its own.
- Then add "stores near you that probably carry it" via a places API.
- Confidence levels last.

### Connection

Pairs naturally with **cuisine personalization** (niche items come from
specific cuisines) and with **notifications** ("grab this on your way home").

---

## V3 — Context-Aware Notifications *(new in v5)*

> Not "come back to the app!" spam. Notifications driven by what the user
> saved and where they are. "You saved that lemon-garlic salmon — on your way
> home you could stop at [store] for the salmon, then make it tonight." The
> notification does a chunk of the planning *for* you.

### Why it matters

Generic re-engagement pings are noise and get muted fast. A notification that
knows *what you wanted to cook* and nudges the one action that makes it happen
(grab the missing ingredient on your commute) is genuinely useful — and useful
notifications are the ones people leave enabled.

### What it would actually look like

- Triggered by **saved meals + time of day + (optionally) location.**
- "Want to make the saved [dish] tonight? You're missing [item] — [store] on
  your route home has it."
- Ties together: saved recipes + pantry gaps + store finder + timing.

### The rule (critical)

Same principle as gamification: **help, never guilt.** No "you haven't cooked
in 3 days." Only forward-looking, actionable, opt-in, and easy to dial down.
One tasteful nudge beats ten ignored ones.

### Stepping stones

- A basic saved-meal reminder ("still want to make X?") — cheap, and the app
  already has a `NotificationScheduler`.
- Add pantry-gap awareness ("you're missing one thing").
- Add location + store routing last (depends on the store finder).

### Connection

This is the surface that makes the store finder + saved meals actually *fire*
at the right moment. It's the glue between features, not a standalone one.
