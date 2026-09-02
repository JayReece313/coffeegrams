# CoffeeGrams — Release 1.2

**Scope: iPad support + an in-app App Store rating prompt.** Both pieces of
work `roadmap_future.md` scoped for 1.2 back when 1.1 shipped.
`MARKETING_VERSION = 1.2`, build `3`.

**Submission runbook: [`submission_1.2.md`](submission_1.2.md)** — the
versioned App Store runbook for this release, alongside
[`submission_1.1.md`](submission_1.1.md) and
[`submission_1.0.md`](submission_1.0.md) for the previous ones. This file is
the *what and why*; the runbook is the *how to ship it*.

**Scope decision (carried from 1.1, 2026-07-29):** iPad was originally
pencilled in as the 1.1 headline feature, but the keypad bug was a live
usability defect that shouldn't wait behind a 1–2 session layout pass — so
1.1 shipped the bug fixes alone and iPad moved here. The in-app rating
prompt joined this release later (decided 2026-08-06, out of the marketing
repo's paid-ads research — see `roadmap_future.md`'s *Where this came from*)
because it's small, and 1.2 was already the next release in flight.

## iPad support

**AS BUILT.** Universal app — `TARGETED_DEVICE_FAMILY = "1,2"` on the app
target. iPhone is unchanged (portrait-only, the exact original
`NavigationStack`); iPad gets its own layout, gated on
`horizontalSizeClass == .regular`.

- **Content width/height capping** — Calculator, GuidedBrew, EspressoShot,
  ColdBrew, Paywall, Log, and LogDetail are capped at 640pt width (centered),
  so nothing stretches edge-to-edge on a 13" screen. A no-op on iPhone,
  already narrower. The three timer screens (GuidedBrew, EspressoShot,
  ColdBrew) needed a second fix: each uses an unbounded `Spacer` to push its
  controls down, which is harmless on iPhone but stretched to fill an iPad's
  full leftover height, stranding the controls far below the content.
  Bounded each `Spacer` at 60pt so the block centers as a compact card
  instead.
- **`NavigationSplitView` for the method picker** — sidebar method list +
  detail pane, so both stay visible together, rather than one replacing the
  other as on iPhone. Chosen over a simpler centered-list alternative after
  comparing both against real device screenshots with the owner. Locked
  (Pro) rows still present the paywall rather than selecting into the detail
  pane, with an `onChange(of: selectedMethod)` fallback in case the primary
  Button-intercepts-the-tap path ever doesn't hold on a future SwiftUI
  change. `.id(selectedMethod)` on the detail column's `NavigationStack`
  resets any pushed state (e.g. a `BrewSessionView`) when the selection
  changes — unreachable today since French Press is the only unlocked
  method, but real for any Pro user with more than one to switch between.
- **iPad App Store screenshots** — `Releases/screenshots/ipad/`, at
  2064×2752 (the *required* 13" size per Apple's current spec, confirmed
  against Apple's own screenshot-specifications documentation rather than
  assumed). `capture.sh` gained `CG_PLATFORM=ipad`. Two capture tests that
  didn't exist before (`testCaptureHome`, `testCapturePaywall`) plus
  `testCaptureBrewLog` were added, rounding `ScreenshotCaptureTests` out to
  all five scenes for both platforms — the tracked iPhone `01-home.png` /
  `04-paywall.png` / `05-brew-log.png` were deliberately **not** regenerated
  by the new tests at the time (05's richer multi-entry look would have been
  downgraded to one plain unrated brew); see §*What's still true from 1.1*
  in the runbook for how those ended up refreshed for this release anyway.
- **Test fix along the way:** `testGuidedBrewSavesToLog`'s
  `navigateBack() × 2` pattern worked by luck on iPhone but could silently
  misnavigate on iPad's split view (the sidebar's own toolbar is always
  visible, so a blind "tap the first nav-bar button" can hit something
  unrelated). Replaced with a reachability-checked `openBrewLog()` helper
  and a stronger nav-bar assertion — confirmed by inspecting the actual
  captured screenshot before the fix, not just green test output.

Shipped via [PR #14](https://github.com/JayReece313/coffeegrams/pull/14) +
a same-PR Qodo-review follow-up commit (one real bug fixed — the detail-stack
reset above — two findings verified and dismissed as false positives, with
the dismissal reasoning left as inline comments at the flagged lines).

## In-app App Store rating prompt

**AS BUILT.** SwiftUI's `requestReview` environment action, gated on 3+
completed brews, 7+ days since first launch, and fired immediately after
saving a brew rated 4–5 stars — the only call site, in `LogDetailView`'s
rating-set flow. Never fires on a paywall dismissal or mid-brew.

- **`ReviewPromptEligibility`** (`CoffeeGramsCore/ReviewPrompt/`) — pure,
  fully tested (12 cases covering every gate boundary). The one part of this
  feature that's genuinely provable, since `requestReview()` gives no
  callback and no return value.
- **`ReviewPromptTrigger`** (`Platform/ReviewPrompt.swift`) — the
  orchestration: persist the rating, and only on success, evaluate
  eligibility and fire. A free function on a `@MainActor` namespace rather
  than a traditional ViewModel, because two of its dependencies
  (`BrewLogStoring`, `ReviewRequesting`) only resolve once the calling View
  reads its environment — before that point no ViewModel could hold them as
  constructor dependencies either. Added after an initial version put this
  logic directly in the View and a Qodo review caught it, along with a real
  bug (a failed rating save could still consume the review-prompt cooldown)
  and a real inefficiency (`@Query`-ing every brew record just to count
  them, replaced with `BrewLogStoring.completedBrewCount()` via
  `fetchCount`).
- **First-launch date** stamped once at real app startup
  (`CoffeeGramsApp.init`, skipped under tests), not lazily on first read —
  otherwise the 7-day clock would start from whenever a view first happened
  to check it.
- **90-day cooldown** between our own prompts isn't specified numerically in
  the original spec, only implied by tracking "last prompt date" at all —
  documented as a reasoned default in `ReviewPromptEligibility`'s doc
  comment.
- **Privacy manifest** — this is the app's first use of `UserDefaults`;
  added the required `NSPrivacyAccessedAPICategoryUserDefaults` declaration
  (reason `CA92.1`, own-app-only data) to `PrivacyInfo.xcprivacy`. App
  Privacy label is unaffected — "Data Not Collected" still holds, since
  nothing is transmitted anywhere.

Shipped via [PR #15](https://github.com/JayReece313/coffeegrams/pull/15) +
a same-branch Qodo-review follow-up commit.

## Decided: NO ads *shown inside the app*

Unchanged from 1.0/1.1 and not up for revisit — see
[`roadmap_future.md`](roadmap_future.md) for the full reasoning.

## Execution checklist

- [x] Branch per unit of work (`feature/1.2-ipad-support`,
      `feature/1.2-rating-prompt`, plus the small cleanup branches along the
      way) so Qodo reviews each PR.
- [x] iPad support — layout pass, `NavigationSplitView`, screenshots.
- [x] In-app rating prompt — eligibility logic, port + adapters, trigger
      wired in.
- [x] Both Qodo reviews driven to zero real findings (false positives
      documented inline, real findings fixed).
- [x] All suites green (Core 61, app unit, `CoffeeGramsUITests`) + iPhone
      and iPad, Debug/Release warning-free.
- [x] `MARKETING_VERSION` bumped to 1.2, `CURRENT_PROJECT_VERSION` to 3.
- [ ] "What's New" copy for the listing (draft below).
- [ ] iPhone screenshots re-verified against the shipped 1.2 build (audited
      2026-09-01 — `01-home`, `02-calculator`, `03-guided-timer`,
      `04-paywall` recaptured and visually confirmed unchanged;
      `05-brew-log` deliberately left as-is, same reasoning as 1.1).
- [ ] iPad screenshots uploaded to the **13" Display** slot in ASC (not the
      legacy 12.9" slot) — see [`submission_1.2.md`](submission_1.2.md).
- [ ] Merge → archive → TestFlight → submit (manual release), following
      [`submission_1.2.md`](submission_1.2.md).

## What's New (draft copy)

> **CoffeeGrams now runs great on iPad.**
>
> • A new sidebar layout shows your brew methods and the calculator side by
>   side — no more switching back and forth.
> • Every screen — calculator, guided timers, brew log, and the paywall —
>   is redesigned to use the extra space instead of stretching thin.
> • Under the hood: small reliability and performance improvements.

The rating prompt isn't mentioned — it's not a feature a user would notice
or want advertised, the same reasoning that kept internal string-catalog
work out of 1.1's What's New.
