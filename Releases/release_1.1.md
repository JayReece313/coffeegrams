# CoffeeGrams — Release 1.1 (planned)

A living roadmap for the next release. v1.0 shipped **iPhone-only, portrait**; the
headline feature for 1.1 is **iPad support**. Add anything we decide for the next
release here so it stays the single source of truth for what 1.1 needs.

## Headline feature: iPad support

**Why it was deferred from 1.0:** our UI was designed for iPhone portrait.
Shipping it "universal" without an iPad layout pass risks looking stretched and
getting rejected for poor iPad optimization. Adding iPad later is a normal,
penalty-free App Store update (same review process), so we ship iPhone first and
do iPad properly in 1.1.

### What needs to change

1. **Re-enable iPad in the build.**
   `Apps/CoffeeGrams/CoffeeGrams/CoffeeGrams.xcodeproj/project.pbxproj` — set
   `TARGETED_DEVICE_FAMILY = "1,2"` (currently `"1"`) on the app target's Debug
   and Release configs.

2. **Decide orientation for iPad.** iPhone stays portrait; iPad users expect to
   rotate. Likely allow all orientations on iPad
   (`UISupportedInterfaceOrientations~ipad`, already present) while keeping
   iPhone portrait-only.

3. **Adapt the layouts** (the real work — the current screens will *run* on iPad
   but look sparse/stretched):
   - Constrain content width on large screens (e.g. `.frame(maxWidth: 640)` +
     centered) for the calculator, guided-brew, paywall, and log-detail screens,
     so forms/readouts don't span a 13" iPad.
   - Consider a **`NavigationSplitView`** for iPad: the method list in a sidebar,
     the calculator/brew in the detail pane (a much better iPad experience than a
     pushed stack). `MethodPickerView` is the place to branch on size class.
   - Verify the big numerals / timer scale sensibly on iPad (they already use
     `@ScaledMetric`).
   - Check tap targets and spacing at iPad sizes.

4. **Testing (add iPad):**
   - Run the existing unit/integration suites (unchanged).
   - Run `CoffeeGramsUITests` on an **iPad simulator** destination too, and add
     any iPad-specific assertions (e.g. split-view navigation).
   - Manual pass on an **iPad simulator + a real iPad**.

5. **App Store Connect:** iPad **screenshots are required** once iPad is
   supported — add 12.9"/13" iPad screenshots to the listing.

### Rough effort
~1–2 focused sessions: layout adaptation + iPad testing. The logic layer
(`CoffeeGramsCore`, ViewModels) needs no changes — this is purely presentation.

## Other candidates for 1.1 (decide before starting)

- **iCloud sync for the brew log** — deferred from M7. Add
  `ModelConfiguration(..., cloudKitDatabase: .automatic)` behind a Settings
  toggle; needs the iCloud capability + a container. (See the CloudKit "seam"
  note in `CoffeeGramsApp.swift`.)
- **Cream launch screen** — one-click in Xcode (target → Info → Launch Screen →
  Background color = `Background`), to remove the white/black launch flash.
- **Custom method icons** — replace the SF Symbol placeholders
  (`BrewMethod+Presentation.swift`) with a bespoke vector set matching the brand
  logo.
- **Free-tier tuning** — if analytics/reviews show the pour-over crowd bouncing
  at the paywall, consider adding **V60** to the free tier (a one-line change in
  `BrewMethod.isFreeTier`).

## Decided: NO ads (owner decision, 2026-07-19)

**We will not put ads in CoffeeGrams.** This is a settled product decision, not a
"maybe later" — recorded here so it isn't re-litigated.

**Why:**
- The brand is **premium + privacy-first**. The store description, privacy policy,
  and privacy manifest ("Data Not Collected", no third-party SDKs, no tracking)
  are a real differentiator. An ad SDK (e.g. AdMob) would falsify all three,
  flip the App Privacy label to "Data Used to Track You", and require an ATT
  prompt — making the listing *look worse*.
- **Revenue wouldn't justify it.** Ads are a volume game (banner eCPM ~$0.20–$1);
  a niche utility with a deliberately small free tier (French Press only) won't
  generate meaningful ad income. A few $4.99 Pro purchases out-earn it without
  degrading the experience.
- **Bad fit for the model.** Pro already unlocks 5 of 6 methods; adding ads on
  top of that thin free tier is double-dipping and invites 1-star reviews on the
  very first release.

**If revenue needs a lever later,** prefer (in order): free-tier tuning (add V60
free — one line in `BrewMethod.isFreeTier`), price experiments, or a "tip jar"
IAP — all keep the privacy story intact. Revisit only with real post-launch
download/usage data, and never as part of a feature release.

## Execution checklist (when 1.1 starts)

- [ ] Branch off `main` (e.g. `release/1.1-ipad`) so Qodo reviews the PR.
- [ ] Re-enable iPad device family; set iPad orientations.
- [ ] Adapt layouts (max content widths; NavigationSplitView for iPad).
- [ ] Run all tests incl. XCUITest on iPhone **and** iPad destinations.
- [ ] Manual pass on iPad device.
- [ ] Bump `MARKETING_VERSION` to 1.1; add iPad screenshots + "What's New" copy.
- [ ] Merge when Qodo is clean; archive → TestFlight → submit.

---

*Update this file as new 1.1 decisions are made.*
