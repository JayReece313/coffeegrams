# CoffeeGrams — v1.2 App Store Submission Runbook (AS-BUILT)

> **Status: 🟢 LIVE on the App Store 2026-09-24.** Submitted **2026-09-23**,
> approved **2026-09-24** — a 1-day turnaround, in the same fast-review range
> as 1.1's same-day approval and well under 1.0's ~9-day wait — and released
> manually the same day.
>
> This is the as-built record, not a plan. What actually differed from the
> plan is in [§5 As-built notes](#5-as-built-notes--what-differed).

`MARKETING_VERSION` **1.2** · `CURRENT_PROJECT_VERSION` **3** · Bundle ID
`com.jrlabapps.CoffeeGrams` · **Universal — iPhone + iPad**, portrait-only
on iPhone, all orientations on iPad. First release where `TARGETED_DEVICE_FAMILY`
is `"1,2"`.

## What makes this different from 1.1

Same shape as 1.1: a version update to an existing, approved app with no new
IAP, so it's the four-step flow, not 1.0's eight. Two things were genuinely
new this time:

| New this release | Why it mattered |
|---|---|
| **A second screenshot set** — iPad, at the **13" Display** size (2064×2752) | This project had picked the wrong ASC screenshot *slot* twice before (6.5" instead of 6.9" for 1.1's upload; nearly the legacy 12.9" instead of the current 13" while researching this release). See §5 for how it actually went. |
| **Rule 2205425's first real test** | The Qodo compliance rule that falsely flagged the submission runbook as missing (documented in memory since 1.1) was edited cloud-side on 2026-08-13. This release's PR (#17) was the first to touch a `Releases/submission_*.md`/`release_*.md` file since — the trigger condition. **Confirmed resolved**, see §5. |

Everything 1.1 already established held, unchanged:

| Skipped | Why |
|---|---|
| §5 of the 1.0 runbook (create the IAP) | `com.jrlabapps.coffeegrams.pro` already existed and was approved. Neither iPad support nor the rating prompt touches IAP. |
| App-level settings (Category, Price, Age Rating, DSA trader) | Persist across versions; 1.2 changed none of them. |
| **App Privacy questionnaire** | 1.2 adds `UserDefaults` (rating-prompt state) and a StoreKit review-request call, both on-device / Apple-framework — no data leaves the device, so "Data Not Collected" still held. Not re-opened. |

---

## Order of operations

1. Merge to `main` with Qodo clean, confirm the version numbers
2. Archive + upload the build
3. Version page (What's New, build, **two screenshot sets**, manual release)
4. Review Submission — one item, same as 1.1

---

## 1. Pre-flight

- [x] **[me]** `MARKETING_VERSION` bumped to **1.2**, `CURRENT_PROJECT_VERSION`
      to **3**, across every build config (verified uniform before the bump —
      6 occurrences each, app target and both test targets).
- [x] **[me]** All suites green + warning-free, verified after the version
      bump: Core **61/61** in 5 suites, app `** TEST SUCCEEDED **` on iPhone
      17 and iPad Pro 13-inch (M5), Release build clean.
- [x] **[you]** **Merged to `main`** — PR #17, commit `b9a73c6`,
      2026-09-23.
- [x] **[you]** **Rule 2205425 — confirmed resolved.** Watched across two
      Qodo review passes on PR #17 (commits `eaedbaa` and `16035d7`), both
      of which touched `submission_1.2.md` and `release_1.2.md` — the exact
      trigger condition. The rule did not fire either time. The 2026-08-13
      cloud-side fix held. See §5.
- [x] **[you]** **Build number checked against TestFlight** — build **3**
      had never been uploaded, upload was clean.

## 2. Archive → upload

- [x] **[you]** Archived from `main` at `b9a73c6` (destination: **Any iOS
      Device (arm64)**).
- [x] **[you]** **Product → Archive**, then **Distribute App → App Store
      Connect → Upload**.
- [x] **[you]** Processing completed without issue.
- [x] **[you]** **TestFlight sanity pass on a real iPhone and a real iPad**
      — passed. iPad sidebar + detail pane confirmed working (method
      selection updates the detail pane correctly), full French Press brew
      end-to-end confirmed on both devices.

## 3. Version page

- [x] **[you]** Version **1.2** created in ASC.
- [x] **[you]** **What's New** copy entered (see *Copy-paste metadata*
      below).
- [x] **[you]** Build selected.
- [x] **[you]** **iPhone screenshots** uploaded — the four re-verified/
      recaptured assets plus the unchanged `05-brew-log.png`.
- [x] **[you]** **iPad screenshots** uploaded to the **13" Display** slot.
      See §5 for how the slot-selection risk this section flagged actually
      played out.
- [x] **[you]** **Version Release** set to **Manually release this
      version**.
- [x] **[you]** Review notes added (no demo account needed).

## 4. Review Submission

- [x] **[you]** **Submitted 2026-09-23**, one item — the 1.2 app version
      only. The IAP was not re-added.
- [x] **[you]** **Submit to App Review** clicked.

## After submitting

- [x] **Approved 2026-09-24** — 1-day turnaround.
- [x] **Released 2026-09-24** — clicked **Release This Version** the same
      day it was approved.
- [x] **[you]** Updated to **AS-BUILT** (this revision).
- [ ] **[you]** Per the Retrospective Standard, add the 1.2 notes to
      `CoffeeGrams_Summary.md` in the private `Summary` repo, including the
      **AI-agent process review** checkpoint. *(Still open — see below.)*

---

## 5. As-built notes — what differed

### Rule 2205425 — confirmed resolved

Watched across both Qodo review passes on PR #17 (commits `eaedbaa` and
`16035d7`), both of which touched `submission_1.2.md` and `release_1.2.md` —
the exact trigger condition documented since 1.1. The rule did not fire
either time. The 2026-08-13 cloud-side fix (instructing the checker to
determine existence from the PR's actual file listing, not from other docs'
headers) held. This closes the loop opened in `submission_1.1.md` §5 — no
further action needed on this rule going forward.

### The string catalog followed the UI changes in, again

Archiving for this release regenerated `Localizable.xcstrings`, exactly as
it did for 1.1 (see `submission_1.1.md` §5, "The string catalog followed the
UI changes in, unnoticed"). Two things happened:

- **Xcode stripped `"isCommentAutoGenerated" : false`** off four keys that
  had deliberately hand-written comments (`+%@`,
  `calculator.dismissKeypad.done`, `guidedBrew.finalStep.done`,
  `guidedBrew.manualStep.next`) — silently reverting them to "auto-generated"
  ownership, which means Xcode could overwrite their (currently still
  correct) text on a future build.
- **Two new keys appeared** from the iPad empty-state screen
  (`MethodPickerView`'s `ContentUnavailableView`, added during the iPad PR
  but apparently never committed with the catalog synced): `"Choose a brew
  method"` and `"Pick a method from the list to start."` — the second with
  **no comment at all**, the same "empty object" defect 1.1 found on
  `"TOTAL"`.

This was caught by reviewing the diff after archiving, before it could ride
into a commit unreviewed — but it's now the **second** release in a row
where this happened. **For next time:** treat `xcstrings` regeneration as an
expected side effect of every archive, not a surprise — diff it immediately
after archiving, before staging anything else, rather than discovering it
buried in a later `git status`. Filed as its own fix (see the fix commit
alongside this update, restoring the four flags and writing real comments
for the two new keys).

### The 13" screenshot slot — no repeat this time

Both screenshot sets — iPhone (existing 6.9" slot) and the new iPad 13"
slot — went smoothly. The device-size selector made the 13" slot easy to
find deliberately, rather than needing to be picked out from a default the
page happened to show. The new-territory risk this section flagged
(picking 13" vs. the legacy 12.9" slot, on top of this project's two prior
screenshot-slot mistakes in 1.1) did not materialize. First clean iPad
screenshot upload for this app.

### What went exactly to plan

- **1-day review turnaround** — in the same fast range as 1.1's same-day
  approval, confirming a small update with no new IAP and no App Privacy
  change continues to review quickly.
- **One review item** — the IAP trap the runbook repeatedly warned about did
  not catch this release either.
- **TestFlight pass on both devices came back clean** — no iPad-specific
  regression surfaced that Simulator testing had missed.

---

## Copy-paste metadata

### What's New in This Version

```
CoffeeGrams now runs great on iPad.

• A new sidebar layout shows your brew methods and the calculator side by side — no more switching back and forth.
• Every screen — calculator, guided timers, brew log, and the paywall — is redesigned to use the extra space instead of stretching thin.
• Under the hood: small reliability and performance improvements.
```

### Unchanged from 1.1 — for reference

- **Support URL:** https://jayreece313.github.io/coffeegrams/support/
- **Privacy Policy URL:** https://jayreece313.github.io/coffeegrams/privacy/
- **Support email:** info@jrlabapps.com
- **Category:** Food & Drink · **Age rating:** 4+
- **IAP:** `com.jrlabapps.coffeegrams.pro` — $4.99, non-consumable, already approved
- **App Privacy:** Data Not Collected (no third-party SDKs, no tracking — still true in 1.2)

---

## Carry these into the next release

- **Diff `Localizable.xcstrings` immediately after every archive**, before
  doing anything else — this is the second release running where archiving
  silently reverted hand-written-comment ownership and added an
  uncommented key. A five-second `git diff` habit catches it before it rides
  into an unrelated commit.
- **Screenshot slot discipline** — pick the ASC device-size slot by the
  selector, never by whichever one the page shows first. Now proven across
  three releases: 1.1's 6.5"/6.9" mixup, this release's near-miss during
  research, and this release's actual upload (both iPhone and the new iPad
  13" slot), which went cleanly. First release where this habit paid off
  rather than caught a mistake after the fact.
- **Archiving from `main` after merge**, checking TestFlight before
  archiving, one item in the Review Submission, not re-answering App
  Privacy — all continue to hold.
