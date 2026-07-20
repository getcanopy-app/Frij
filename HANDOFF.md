# Frij — Session Handoff

Paste the block below into a fresh Claude Code session to pick up where we left off.
Last verified: 2026-07-20.

---

## PROMPT — copy everything below this line

I'm Kevin, working on **Frij**, an iOS app (SwiftUI) that scans your fridge and
suggests recipes. Repo: `~/Developer/Frij`. Read `HANDOFF.md` in that repo first,
then verify anything you rely on against the actual code — this doc goes stale.

**Where things stand:** the app is code-complete and submission-ready. Every
launch blocker except one is closed.

**The ONE blocker:** my Apple Developer Program account hasn't activated yet
(I paid/enrolled; I'm in Brazil so it's slow). You cannot check this — no Apple
tooling is connected. The signal is Apple's "Welcome to the Apple Developer
Program" email. When I say "it's active," walk me through App Store Connect
step by step, live.

**Facts you can rely on (all verified 2026-07-20):**
- Branch `dev`, clean, synced with `origin/dev`. Latest commit `443a434`.
- Git auth is **SSH** (`git@github.com:getcanopy-app/Frij.git`). Personal access
  tokens do NOT work — the repo is in the `getcanopy-app` org and fine-grained
  PATs get 403 on push. Never send me down the PAT route again.
- Bundle ID: `com.hellofrij.frij` (tests: `.tests` / `.uitests`). Version 1.0,
  build 2. iPhone-only, app sandbox + hardened runtime on.
- Subscriptions: `com.frij.plus.monthly` ($2.99/mo), `com.frij.plus.annual`
  ($19.99/yr) — IDs live in `Fridj/SubscriptionManager.swift:11-12`.
- Paywall is `Fridj/PaywallView.swift`. It was audited against App Store Review
  Guideline 3.1.2 and **passed** — name, prices, billing periods, auto-renewal
  disclosure (line ~388), and live Terms + Privacy links are all present.
- Legal pages live and verified 200: https://hellofrij.com/terms and
  https://hellofrij.com/privacy, contact support@hellofrij.com. URLs are
  centralized in `Fridj/FrijLinks.swift`. Domain is on Cloudflare; email routing
  to gabriel.nejad@gmail.com works (tested with a real email).
- App Store listing copy is drafted and screenshots are captured (1290×2796, on
  my Desktop). Final ordered set: IMG_7076 → IMG_7078 → IMG_7071 → IMG_7070 →
  IMG_7072, optional IMG_7075. Do NOT use IMG_7074 (shows my selfies) or
  IMG_7077 (wrong size).
- No auth in the app by design — local storage + StoreKit only. Do not add
  email/password. Sign in with Apple is a maybe for later, not now.
- Backend testing rule: use **Vercel preview deploys, never production**, unless
  I explicitly approve prod.

**When my account activates, the App Store Connect checklist is:**
1. Business → sign Paid Apps Agreement, add banking + tax info (open question:
   file as an individual with a W-8BEN, or set up an LLC — cross-border US/Brazil,
   I may need a real accountant here).
2. Create the app record with bundle `com.hellofrij.frij`. Heads up: the App
   Store name must be globally unique and a competitor ("frij — No food goes to
   waste" by Adera Express, launched 2026-07-02) is in the same niche. No app is
   titled exactly "Frij," so it should be claimable — fallback name is
   "Frij: Fridge to Recipes". I already decided to KEEP the name; don't reopen it.
3. Create the subscription group and both products at the exact IDs/prices above.
4. Privacy nutrition label: Photos, Device ID, Purchases → all "App Functionality."
5. Paste listing copy, upload screenshots, fill the Privacy Policy URL field with
   https://hellofrij.com/privacy.
6. Archive → TestFlight → submit for review.

**Open items, none blocking:** ask Ardalan whether frij-backend stores scan photos
(if not, tighten Privacy §5 from "may be briefly retained" to "not stored after
processing"); decide individual vs LLC for tax.

**How I want you to work:** verify every change actually works in the same turn —
build it, curl the URL, run the test — never just tell me it's done. I'm not a
deep engineer, so explain things plainly and give me exact click-by-click steps
for anything I have to do myself in a browser.

## END OF PROMPT
