# CoffeeGrams — Future releases

Work decided or considered but **not** in 1.1. 1.1 shipped the 1.0 bug fixes and
the timer overhaul only (see [`release_1.1.md`](release_1.1.md)); everything
below was deferred so those fixes could reach users without waiting on a layout
pass or a CloudKit container.

Add anything we decide for a future release here so it stays the single source
of truth. Move a section into its own `release_<version>.md` when that release
actually starts.

## 1.2 — iPad support (next up)

**Status: not started.** `TARGETED_DEVICE_FAMILY = 1` on every build config. The
`UISupportedInterfaceOrientations~ipad` keys are already in the project and are
inert while iPad is off, so that part is free when we flip the switch.


**Why it was deferred from 1.0:** our UI was designed for iPhone portrait.
Shipping it "universal" without an iPad layout pass risks looking stretched and
getting rejected for poor iPad optimization. Adding iPad later is a normal,
penalty-free App Store update (same review process), so we shipped iPhone first.
It was deferred again out of 1.1, which carried the 1.0 bug fixes and the timer
overhaul only — iPad is 1.2.

### Which model to use

Decided up front so a 1.2 session doesn't default to whatever is already open.
1.1's closeout ran on Opus and mostly didn't need to.

| Task | Model | Why |
|---|---|---|
| **iPad layout pass** — content-width constraints, `NavigationSplitView`, spacing/tap targets | **Sonnet 5** | Presentation work against a written spec (the list below). High volume, low ambiguity — near-Opus quality at ~60% of the cost |
| Re-enable `TARGETED_DEVICE_FAMILY`, orientation keys | **Sonnet 5** | Mechanical build-setting edits |
| iPad screenshots + extending the capture harness | **Sonnet 5** | Scripted, deterministic, already-solved pattern |
| Split the `Done` string key | **Sonnet 5** | Small, well-specified refactor |
| UI tests + iPad assertions | **Sonnet 5** | Routine test work |
| **App Store "What's New", any listing copy** | **Opus 5** | ~200 words. The cost is a rounding error and prose voice is the deliverable — economising here is false thrift |
| A genuinely ambiguous design call (e.g. sidebar vs. stack if the spec below turns out not to settle it) | **Opus 5** | Escalate *deliberately*, not by default |

**Rule of thumb:** start 1.2 on Sonnet 5 and switch with `/model` only when you
hit a real judgement call. See *Cost & Context Efficiency* in
[`../CLAUDE.md`](../CLAUDE.md) for the standing guidance.

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

## 1.3+ — iCloud sync for the brew log

Deferred from M7, and again from 1.1. **Not started** — the only thing in the
codebase today is the seam comment in `CoffeeGramsApp.swift`. There is no
entitlement, no container, and no `cloudKitDatabase:` configuration.

It is bigger than the original one-line note suggested. Three separate pieces:

1. **Capability + container** — enable iCloud on the App ID and create a
   CloudKit container in the Developer portal. Portal work, outside the code.
2. **Schema rework** — SwiftData + CloudKit requires every model property to be
   optional **or carry a default value**. `BrewLogRecord`'s properties take
   defaults in the *initialiser* but not on the properties themselves, so the
   model needs changing before it can sync. (`plannedSeconds` / `actualSeconds`,
   added in 1.1, are already optional and fine.)
3. **A Settings screen** — the plan says "behind a Settings toggle", but **there
   is no Settings screen**. Features today are Calculator, GuidedBrew, Log,
   MethodPicker and Paywall. That screen has to be built first, which makes this
   a genuine feature release rather than a config change.

Also worth deciding before starting: conflict behaviour when the same brew is
edited on two devices, and whether syncing changes the App Privacy answer
(data in the user's *own* private CloudKit database is normally not "collected"
by us, so the "Data Not Collected" label should hold — but confirm, don't
assume).

## Smaller candidates (unscheduled)

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

