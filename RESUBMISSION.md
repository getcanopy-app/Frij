# 1.0 (build 10) Resubmission Kit

## Resolution Center reply (paste this when resubmitting)

Hello, and thank you for the detailed review. We have addressed every issue:

**Guideline 2.1(a) — error after tapping Your Kitchen:** This was caused by a
temporary outage of our recipe service during the review window. The service
has been restored, hardened, and verified end to end (scanning, recipe
generation, and photo generation). The scan flow now also handles photos with
no identifiable food gracefully instead of showing an error.

**Guideline 4 — iPad layout:** The app is now iPhone-only
(TARGETED_DEVICE_FAMILY = iPhone). On iPad it runs in the standard
"Designed for iPhone" compatibility mode.

**Guideline 5.1.1(ii) — photo library purpose strings:** Both photo library
purpose strings have been rewritten to state the specific use with a concrete
example (choosing an existing fridge photo so Frij can identify ingredients;
saving captured fridge photos for later re-scanning).

**Guideline 2.3.7 — pricing in screenshots:** The screenshot referencing
subscription pricing has been removed from the app's metadata.

**Guideline 2.1(b) — In-App Purchases:** The auto-renewable subscriptions
(com.frij.plus.monthly, com.frij.plus.annual) are implemented via StoreKit 2
and are attached to this version. A screen recording of a successful sandbox
purchase on a physical device is attached in the App Review Information notes.

Thank you again — we appreciate the specific feedback.

## App Review Information → Notes field

Frij generates dinner ideas from the ingredients in your kitchen.

To test the core flow: tap Scan on the Home screen and photograph any food
(or use "Your kitchen" to type ingredients such as "chicken, rice, broccoli"),
then tap "Get 3 dinners from this."

Frij+ subscriptions: reachable at any time via Profile (top-left icon on
Home) → Frij+. A screen recording of a successful sandbox purchase on a
physical device is attached. Product IDs: com.frij.plus.monthly,
com.frij.plus.annual.

No account or login is required to use the app.

## Submission checklist (in order)

1. [ ] Archive 1.0 build 10 in Xcode (Product → Archive, scheme Fridj,
       Any iOS Device) → Distribute → App Store Connect → Upload
2. [ ] ASC → Frij → version 1.0 → select build 10
3. [ ] Replace screenshots with the new 6.9" set (AppStore-Screenshots/)
4. [ ] In-App Purchases section on the version page → ensure both
       subscriptions are attached
5. [ ] Record sandbox purchase video on iPhone (sandbox tester signed in
       under Settings → Developer → Sandbox Apple Account):
       Home Screen → launch Frij → scan/generate → Profile → Frij+ →
       subscribe monthly → [Environment: Sandbox] sheet → confirm → success
6. [ ] Attach video + paste Notes text in App Review Information
7. [ ] Paste the Resolution Center reply
8. [ ] Confirm auto-release setting is still "automatically release"
9. [ ] Submit for Review (returns to the expedited queue per Apple's message)
