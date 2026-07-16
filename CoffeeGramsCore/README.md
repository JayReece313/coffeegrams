# CoffeeGramsCore

The pure, UI-free heart of **CoffeeGrams** — brewing data, calculations,
timeline generation, and the guided-brew timer. No SwiftUI, UIKit, or SwiftData
imports, so it compiles and is fully unit-tested from the command line, long
before the iOS UI exists.

## Why a separate package?

1. **Testability.** Every brewing number in the spec is a `#expect` assertion.
   Because there is no UI here, the suite runs in milliseconds on any Mac.
2. **A clean boundary.** The iOS app depends on this package and supplies the
   "live" implementations of the `Ports` protocols (clock, notifications,
   haptics, purchases, storage). Logic and platform never bleed into each other.
3. **Reuse.** A widget or watchOS app later can link the same core.

## Layout

```
Sources/CoffeeGramsCore/
  Models/       BrewMethod, BrewType, BrewMethodProfile, BrewStep,
                BrewLogEntry, EspressoTarget/ShotTimingState, ColdBrew*
  Calculator/   BrewCalculator — pure water/dose math + ratio clamping (spec §4.1)
  Timeline/     BrewTimeline + BrewTimelineBuilder (spec §4.2–4.6)
  Timer/        BrewTimerEngine — deterministic guided-brew state machine
  Ports/        MonotonicClock (protocols the app implements)
Tests/CoffeeGramsCoreTests/   Swift Testing suites, one per layer
```

## Running the tests

This machine has the **Command Line Tools**, not full Xcode, so plain
`swift test` can't find the Swift Testing framework or its macro plugin. Use the
wrapper, which passes the right search paths at invocation time (keeping
`Package.swift` clean so it still builds natively in Xcode):

```sh
./test.sh                 # run everything
./test.sh --filter Timer  # forward extra args to `swift test`
```

Inside full Xcode, no wrapper is needed — `⌘U` just works.

## Design notes

- **The timer is driven by time deltas, not a clock.** `BrewTimerEngine`
  advances via `advance(by:)`; the app measures real seconds with a
  `MonotonicClock` and feeds them in. That inversion is why a four-minute brew
  is tested in microseconds. Manual steps (plunge, drawdown) *hold* the machine
  until the user taps next — they never time out.
- **Value types in Core, `@Model` in the app.** `BrewLogEntry` is a plain
  struct here; the app defines a SwiftData model and maps to/from it.
- **Ratios are clamped everywhere.** The slider is bounded, but
  `BrewCalculator.clampRatio` protects every path that consumes a ratio.
- **Known v1 simplification:** immersion-grounds water absorption is *not*
  modelled (documented in `BrewCalculator.doseGrams`). Deferred to v2.

## Status

Milestones **M1–M4** of the build plan are complete and green (41 tests). The
iOS app layer (M5+) is built in Xcode and consumes this package.
