# CoffeeGrams — v1 Build Spec

App name: **CoffeeGrams**. Developed under JR Labs LLC. Hand this doc to Claude Code as the source of truth for scope and brewing math. Everything here is scoped for a first shippable version — no Bluetooth scales, no AR, no social features, no server backend.

## 1. v1 Scope

- 6 brew methods: **V60, Chemex, French Press, AeroPress, Cold Brew, Espresso**
- Two calculator modes: dose-first (enter coffee grams, get water) and yield-first (enter desired cups/ml, get coffee)
- Guided pour/steep timer per method, driven by the step engine in Section 4
- Espresso is scoped down deliberately: dose, ratio slider, target yield, and a shot timer with a target time window. No dial-in, no extraction %, no TDS/refractometer tools — that's the exact feature bloat that draws paywall complaints on Filtru, and it needs hardware (grinder feedback, a scale under the portafilter) the app can't provide anyway.
- Local brew log (SwiftData) with optional CloudKit sync — no custom backend, no server cost
- Monetization: free with 1-2 methods unlocked (V60 + French Press), one-time IAP unlocks the rest + brew log + timer. No subscription tier.
- Explicitly out of scope for v1: Bluetooth scale integration, AR gear previews, community/social recipes, espresso dial-in/extraction tools (see above)

## 2. Data Model

```swift
enum BrewMethod: String, CaseIterable {
    case v60, chemex, frenchPress, aeropress, coldBrew, espresso
}

struct BrewMethodProfile {
    let method: BrewMethod
    let brewType: BrewType          // .pulsePour, .immersion, or .pressure
    let defaultRatio: Double        // water:coffee (or yield:dose for espresso), e.g. 16.0 means 1:16
    let ratioRange: ClosedRange<Double>
    let bloomMultiplier: Double?    // x * doseGrams = bloom water; nil if no bloom
    let bloomSeconds: Int?
    let steepSeconds: Int?          // for immersion methods
    let numPours: Int?              // pulse pour methods only
    let pourIntervalSeconds: Int?
    let shotTimeRangeSeconds: ClosedRange<Int>?  // espresso only — target shot window
}

enum BrewType {
    case pulsePour   // V60, Chemex
    case immersion   // French Press, AeroPress, Cold Brew
    case pressure    // Espresso
}

struct BrewLogEntry {
    let id: UUID
    let date: Date
    let method: BrewMethod
    let doseGrams: Double
    let waterGrams: Double   // for espresso, this stores shot yield grams — same field, different meaning
    let ratio: Double
    let shotSeconds: Int?    // espresso only, nil for every other method
    let rating: Int?        // 1-5, optional
    let notes: String?
}
```

## 3. Ratio & Timing Reference Table

| Method | Type | Default Ratio | Range | Bloom | Brew/Steep Time |
|---|---|---|---|---|---|
| V60 | Pulse pour | 1:16 | 1:15–1:17 | 2.0–2.5x dose, 45s | ~2:30–3:00 total |
| Chemex | Pulse pour | 1:16 | 1:15–1:17 | 2–3x dose, 30–45s | ~3:30–4:30 total |
| French Press | Immersion | 1:15 | 1:12–1:17 | 2x dose, 30s (optional) | 4:00 steep |
| AeroPress | Immersion + press | 1:18 | 1:12–1:18 | none | 2:00 steep + ~1:00 press routine |
| Cold Brew (concentrate) | Immersion, no heat | 1:5 | 1:4–1:5 | none | 12–18h room temp, 18–24h fridge |
| Cold Brew (ready-to-drink) | Immersion, no heat | 1:8 | fixed | none | same as above |
| Espresso | Pressure | 1:2 | 1:1–1:3 | none | 25–30s target shot window |

Sourced from standard brewing references (Hoffmann's Ultimate AeroPress Technique for the 1:18 default; Tetsu Kasuya's 4:6 method informed the V60 pulse-pour cadence). Treat all of these as defaults, not gospel — the UI should let users drag the ratio within the listed range, since taste preference and bean freshness shift the "right" number.

## 4. Calculation Logic

### 4.1 Core formulas (both directions)

```swift
// Dose-first
func waterGrams(doseGrams: Double, ratio: Double) -> Double {
    doseGrams * ratio
}

// Yield-first (user wants e.g. 500g of finished coffee)
func doseGrams(targetYieldGrams: Double, ratio: Double, method: BrewMethod) -> Double {
    // Immersion methods lose water to grounds absorption (~2x dose grams
    // stays trapped in French press/AeroPress grounds). Pulse-pour methods
    // pass all water through, so yield ≈ water poured.
    switch method {
    case .v60, .chemex:
        return targetYieldGrams / ratio
    case .frenchPress, .aeropress:
        // account for absorption: actual water needed is slightly higher
        // than targetYield / ratio. Simple v1 approximation: +2g water
        // retained per 1g coffee dose.
        let rawDose = targetYieldGrams / ratio
        return rawDose // refine with absorption offset in v2 if accuracy complaints show up
    case .coldBrew:
        return targetYieldGrams / ratio
    }
}
```

Keep the absorption correction out of v1 — it's a real effect but a minor one at this precision level, and modeling it convincingly needs testing against real output. Note it in-code as a known simplification so it's not forgotten.

### 4.2 V60 / Chemex — pulse pour timeline generator

```swift
func buildPulsePourTimeline(doseGrams: Double, ratio: Double, profile: BrewMethodProfile) -> [BrewStep] {
    let totalWater = doseGrams * ratio
    let bloomWater = doseGrams * (profile.bloomMultiplier ?? 2.25)
    let remainingWater = totalWater - bloomWater
    let pourAmount = remainingWater / Double(profile.numPours ?? 2)

    var steps: [BrewStep] = []
    var elapsed = 0
    var cumulativeWater = 0.0

    steps.append(.bloom(targetGrams: bloomWater, durationSec: profile.bloomSeconds ?? 45))
    cumulativeWater += bloomWater
    elapsed += profile.bloomSeconds ?? 45

    for i in 1...(profile.numPours ?? 2) {
        cumulativeWater += pourAmount
        steps.append(.pour(pourNumber: i, targetCumulativeGrams: cumulativeWater, startSec: elapsed))
        elapsed += profile.pourIntervalSeconds ?? 45
    }

    steps.append(.drawdown(untilDripsStop: true))
    return steps
}
```

**V60 defaults:** bloom = 2.25x dose, 45s bloom, 2 pours, 45s between pours.
**Chemex defaults:** bloom = 2.5x dose, 30–45s bloom, 2 pours, 60s between pours (Chemex filter is thicker, drains slower — space pours out more).

### 4.3 French Press — bloom + single fill + steep

```swift
func buildFrenchPressTimeline(doseGrams: Double, ratio: Double) -> [BrewStep] {
    let totalWater = doseGrams * ratio
    let bloomWater = doseGrams * 2.0
    return [
        .bloom(targetGrams: bloomWater, durationSec: 30),
        .pour(pourNumber: 1, targetCumulativeGrams: totalWater, startSec: 30),
        .steep(durationSec: 240),   // 4:00, timer starts after full pour
        .plunge
    ]
}
```

No pulse pours — bloom, then fill the rest in one pour, lid on, steep 4 minutes, plunge, serve immediately (leaving coffee on the grounds past ~5-10 min turns it bitter — worth a push notification reminder, not just a timer that stops).

### 4.4 AeroPress — steep + press, ratio as a strength slider

AeroPress recipe culture is genuinely split (inverted vs. standard, short steep vs. long steep), more than the other methods. Rather than pick one "correct" ratio, expose a strength slider from 1:12 (strong/classic) to 1:18 (Hoffmann's light/clean style), defaulting to 1:18.

```swift
func buildAeroPressTimeline(doseGrams: Double, ratio: Double) -> [BrewStep] {
    let totalWater = doseGrams * ratio
    return [
        .pour(pourNumber: 1, targetCumulativeGrams: totalWater, startSec: 0), // pour all at once, ~10s
        .steep(durationSec: 120),   // 2:00
        .stir(durationSec: 10),     // swirl/stir at end of steep
        .wait(durationSec: 30),     // let grounds settle
        .plunge
    ]
}
```

Ship 2-3 named presets on top of the raw slider so it doesn't feel like an empty number field: "Hoffmann Standard" (11g:200g, 1:18), "Classic Strong" (1:12, inverted-style steep).

### 4.5 Cold Brew — no active timer, long-duration notification instead

This is the one method where a live pour timer makes no sense — it's a 12–24 hour steep. Don't force it into the same UI as the others.

```swift
func buildColdBrewPlan(doseGrams: Double, style: ColdBrewStyle, steepHours: Double) -> ColdBrewPlan {
    let ratio: Double = style == .concentrate ? 5.0 : 8.0
    let waterGrams = doseGrams * ratio
    return ColdBrewPlan(
        doseGrams: doseGrams,
        waterGrams: waterGrams,
        steepHours: steepHours,     // default 16, range 12-24
        notifyAt: Date().addingTimeInterval(steepHours * 3600)
    )
}
```

Combine coarse grounds + room-temp or cold water in one step, no bloom, no pulse pour. Schedule a local notification for when steep time is up. Filtering (through a paper filter or fine mesh) is a manual step the app just instructs, not something to time.

### 4.6 Espresso — dose, ratio, yield, shot timer (deliberately shallow)

Espresso doesn't fit the "water poured over/through grounds" model the other five methods share — it's liquid *extracted* under pressure, and the number that matters is shot yield weight versus dose weight, not water added. Keep this method to exactly four inputs/outputs: dose in, ratio, target yield out, and a shot timer with a target window. No dial-in, no extraction percentage, no TDS/refractometer input — those require a Bluetooth scale under the portafilter and grinder feedback the app has no way to get in v1, and it's the exact feature creep that turns a calculator into a maintenance burden (see the Filtru review complaining about not being able to tweak a shot after pulling — that's the rabbit hole this section is designed to avoid).

```swift
func buildEspressoTarget(doseGrams: Double, ratio: Double) -> EspressoTarget {
    let yieldGrams = doseGrams * ratio
    return EspressoTarget(
        doseGrams: doseGrams,
        targetYieldGrams: yieldGrams,
        shotTimeRange: 25...30   // seconds — standard "normale" guideline
    )
}

struct EspressoTarget {
    let doseGrams: Double
    let targetYieldGrams: Double
    let shotTimeRange: ClosedRange<Int>
}
```

**Ratio slider (1:1–1:3, default 1:2):**
- 1:1–1:1.5 → ristretto (short, concentrated)
- 1:2 → normale (the SCA-style default: 18g dose in, 36g out)
- 1:2.5–1:3 → lungo (longer, more diluted)

**Flow:** user enters dose (default 18g), picks a ratio point on the slider, app shows target yield in grams. User starts the timer when they start the shot, watches the target yield fill as they weigh the cup (manual — no scale integration in v1), and the timer shows green inside the 25–30s window, amber/red outside it. No troubleshooting copy like "shot too fast, grind finer" — that's a dial-in feature, not a calculator feature, and it's explicitly deferred to v2 if it ever gets built at all.

## 5. Suggested File/Module Breakdown

- `BrewMethod.swift` — enum + `BrewMethodProfile` static data (the table in Section 3, hardcoded)
- `BrewCalculator.swift` — pure functions from Section 4, no UI dependencies, easiest to unit test first
- `BrewTimerEngine.swift` — state machine that walks a `[BrewStep]` array, fires haptics/sound at step transitions
- `BrewLogEntry.swift` + SwiftData model — local persistence, CloudKit sync as a toggle in Settings
- Views: `MethodPickerView`, `CalculatorView` (dose/yield toggle), `GuidedBrewView` (timer + step list — espresso uses a simplified start/stop variant of this view, not a separate screen), `LogView` (history, ratings, notes)

Build and unit-test `BrewCalculator.swift` before touching any UI — every number in Section 3 is a testable assertion (e.g. `waterGrams(dose: 16, ratio: 16) == 256`), and Claude Code can write those tests straight from this table.
