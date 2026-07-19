# CoffeeGrams — Testing

How CoffeeGrams is tested, across every level of the classic testing pyramid,
plus the exact commands to run each. This is the reference for verifying the app
before each release.

## Summary

| Level | Status | Tool | Where |
|---|---|---|---|
| **Unit** | ✅ Extensive | Swift Testing | `CoffeeGramsCore/Tests`, `CoffeeGramsTests` |
| **Integration** | ✅ Partial | Swift Testing | ViewModel↔Core engine, `BrewLogStore`↔SwiftData |
| **System (automated)** | ✅ Core flows | XCTest / XCUITest | `CoffeeGramsUITests` |
| **System (manual)** | ✅ Ongoing | Simulator + device | exploratory |
| **Regression** | ✅ Continuous | full suite re-run | every change |
| **Static / independent review** | ✅ | Qodo (PR review) | GitHub PRs |

Totals: **~41 Core unit tests + ~36 app unit/integration tests** (4 live-SwiftData
tests gated behind `COFFEEGRAMS_SWIFTDATA_TESTS`) **+ 4 XCUITest system flows.**

---

## 1. Unit testing — isolate one small piece

The strongest layer. Pure, deterministic, fast.

- **`CoffeeGramsCore/Tests/`** (Swift Testing): `BrewCalculator` (dose/water math,
  clamping), `BrewMethodProfile` (§3 reference table), `BrewTimelineBuilder`
  (all six methods), `BrewTimerEngine` (state machine, driven by a fake clock).
- **`CoffeeGramsTests/`** (Swift Testing): each ViewModel
  (`CalculatorViewModel`, `GuidedBrewViewModel`, `EspressoShotViewModel`,
  `ColdBrewViewModel`, `PurchaseController`), plus `BrewReminder`, `TimeFormat`,
  and `BrewStep` presentation.

Run:
```sh
# Core (from the package dir)
cd CoffeeGramsCore && swift test

# App unit/integration
xcodebuild test -scheme CoffeeGrams \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CoffeeGramsTests
```

## 2. Integration testing — components working together

Verified where two real components meet:

- **`BrewLogStoreTests`** exercises `BrewLogStore` against a **real SwiftData
  `ModelContainer`** (service ↔ Apple persistence). Gated behind an env var
  because SwiftData traps under Swift Testing's parallelism (passes in isolation):
  ```sh
  COFFEEGRAMS_SWIFTDATA_TESTS=1 xcodebuild test -scheme CoffeeGrams \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:CoffeeGramsTests/AppTests/BrewLogStore
  ```
- **`GuidedBrewViewModelTests` / `EspressoShotViewModelTests`** run the app's
  ViewModel against the **real `BrewTimerEngine`** from Core (app ↔ Core boundary),
  advancing a fake clock through a full brew.

*Gap:* no single automated test for the full multi-feature chain
(build timeline → run timer → save entry → query log). Each link is tested; the
end-to-end chain is covered by the system tests below.

## 3. System testing — the whole app, as a user

### Automated (XCUITest) — `CoffeeGramsUITests`
Drive the real app in the simulator:
- `testHomeShowsBrandAndMethods` — launch shows the branded home + method list.
- `testFreeMethodOpensCalculator` — French Press (free) opens its calculator.
- `testLockedMethodShowsPaywall` — a Pro method presents the paywall + Restore.
- `testGuidedBrewSavesToLog` — run a full guided brew → Save → it appears in the log.

Run (Xcode: ⌘U, or CLI):
```sh
xcodebuild test -scheme CoffeeGrams \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CoffeeGramsUITests
```

### Manual / exploratory
Throughout development: launching on the simulator to verify flows (calculator,
running timer, paywall gating, Dynamic Type scaling) and confirming brew-log
**persistence across a cold relaunch**. Still to do once per release:
**a pass on a real device** (real StoreKit sandbox, haptics, VoiceOver,
performance) — the one thing a simulator can't cover.

## 4. Regression testing — nothing old breaks

Done continuously: the full unit/integration suite is re-run after **every**
change (each milestone, each fix). This has caught real regressions (e.g. a
SwiftData crash that only surfaced running the whole suite). The XCUITest flows
add **UI regression** protection so a future UI change can't silently break the
core path.

Full regression run:
```sh
xcodebuild test -scheme CoffeeGrams \
  -destination 'platform=iOS Simulator,name=iPhone 17'
cd CoffeeGramsCore && swift test
```

## 5. Independent review (bonus)

Every PR is auto-reviewed by **Qodo** (bugs, rule violations, security). The v1
codebase was taken to **0 bugs / 0 rule violations**. Workflow: branch → PR →
Qodo review → merge when clean.

## Before each release

1. `swift test` (Core) — green.
2. `xcodebuild test -only-testing:CoffeeGramsTests` — green.
3. `xcodebuild test -only-testing:CoffeeGramsUITests` — green.
4. (Once) `COFFEEGRAMS_SWIFTDATA_TESTS=1 …/BrewLogStore` — green in isolation.
5. Manual pass on a **real device**.
6. Open a PR; confirm Qodo is clean.
