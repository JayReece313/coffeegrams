# CoffeeGrams — Release 1.1

**Scope: bug fixes + the timer overhaul. iPhone-only, portrait (unchanged from
1.0).** `MARKETING_VERSION = 1.1`, build `2`.

**Scope decision (owner, 2026-07-29):** 1.1 ships the three fixes below **on
their own**. iPad was originally pencilled in as the 1.1 headline feature, but
the keypad bug is a live usability defect in the shipped app and holding the fix
behind a 1–2 session iPad layout pass helps nobody — version numbers are free.
iPad moves to **1.2** and iCloud sync to **1.3+**; both are tracked in
[`roadmap_future.md`](roadmap_future.md).

## Bug fixes & UX improvements (from 1.0 device testing)

### 1. BUG — decimal keypad won't dismiss on the Calculator ✅ FIXED
- **Symptom:** tapping the **Coffee dose** field raises the number pad, which
  stays up (covering the Start Brew button) until you navigate away. Confirmed on
  device + simulator.
- **Cause:** the dose `TextField` in `CalculatorView.swift` uses
  `.keyboardType(.decimalPad)`, which has **no Return/Done key**, and the screen
  has no dismiss affordance (no focus toolbar, no tap-to-dismiss).
- **Fix (1.1):** add keyboard dismissal — a `@FocusState` + a keyboard toolbar
  **"Done"** button (`ToolbarItemGroup(placement: .keyboard)`), plus
  `.scrollDismissesKeyboard(.interactively)` on the `Form` and/or tap-to-dismiss.
  The toolbar "Done" is the standard, most discoverable fix for numeric keypads.
  Applies anywhere we use `.decimalPad`/`.numberPad`.
- **AS BUILT:** `@FocusState` + `ToolbarItemGroup(placement: .keyboard)` with a
  right-aligned **Done**, plus `.scrollDismissesKeyboard(.interactively)` on the
  `Form` for a gestural second affordance. The dose field is the only
  `.decimalPad` in the app, so this is the complete fix.

### 2. UX — duplicate "Start Brew" (Calculator → Timer) ✅ FIXED
- **Symptom:** "Start Brew" on the calculator only *navigates* to the timer, which
  shows a **second, identical "Start Brew"** to actually start the countdown — two
  taps, confusing.
- **Cause:** `CalculatorView.swift` sets `startBrew = true` (navigate only);
  `GuidedBrewView` in its idle state shows its own "Start Brew" → `vm.start()`.
- **Options considered (researched real brew-timer apps):**
  - **A — Keep two steps, but relabel (RECOMMENDED).** Brew apps intentionally
    start the clock on a deliberate press *after* you've prepared (grind, boil,
    zero the scale) — auto-starting would mistime the first pour, which undercuts a
    *precision* app. Keep the deliberate start, but rename the **calculator**
    button to **"Set Up Brew"** (or "Continue"/"Prepare") and the **timer** button
    to **"Start Timer"** → removes the duplicate-label confusion, keeps accurate
    timing. Small, low-risk change.
  - **B — Auto-start on navigation (owner's initial idea).** One tap, but the
    countdown begins before you're physically ready → worse first-pour accuracy.
    Not recommended as-is.
  - **C — Auto-navigate + a "get ready" buffer.** Open the timer with a 3-2-1
    "get ready" countdown or a big "tap anywhere to start," so it's one intent yet
    still accurately timed. More work; a fallback if we want fewer taps than A.
- **DECISION (owner):** ✅ **Option A** — relabel only: **"Set Up Brew"** on the
  calculator and **"Start Timer"** on the timer screen; keep the deliberate
  two-step start (accurate first-pour timing). **No auto-start.**
- **AS BUILT:** `BrewSessionView.startTitle(for:)` now returns **"Set Up Brew"**
  (and **"Set Up Shot"** for espresso, which had the same duplicate-label
  problem; cold brew keeps "View Plan"). `GuidedBrewView`'s idle button is
  **"Start Timer"**. The XCUITest was updated to the new label.

### 3. TIMER — continuous elapsed clock + explicit Start/Stop + log actual time ✅ CONFIRMED
- **What happens today:** each step is a **countdown**. Timed steps
  **auto-advance** at 0 (a slow pour gets left behind); manual steps (plunge,
  drawdown) **wait indefinitely**. There's a **Pause** button (+ Skip) but no
  continuous total clock and no clean way to *end* a brew mid-way.
- **Research:** countdown is best for step guidance (keep it), but good brew
  timers add a **count-up total-elapsed clock** too → do **both**, not either/or.
- **Proposal (hybrid):**
  - Add a **continuous count-up "total elapsed" master clock** (runs Start → Done)
    alongside the per-step countdown — fixes "what if a brew runs longer."
  - **Controls:** a **Start/Stop toggle** (one button: Start → Pause/Resume) **+ a
    Done** button to finish the brew, side-by-side at the bottom (iOS convention;
    the screen already uses two bottom buttons). Keep Skip as tertiary.
  - **Design call:** when a timed step hits 0, keep **auto-advance** (current) or
    switch to **soft targets** (count past the target, wait for the user's tap).
    Leaning *soft targets* (more forgiving) — decide when building.
    → **DECIDED (owner, 2026-07-29): the overrun counter applies to the brew's
    LAST step only; every other step auto-advances exactly as in 1.0.**
    A first pass put soft targets on all hands-on steps (bloom/pour/stir) and
    was rejected on feel — it meant a tap between every pour, which is not what
    a guided brew should ask for. The 1.0 flow, where each step simply flows
    into the next, stands. What 1.0 lacked was any notion of *going over*, and
    the place that matters is the end of the brew: the final step (the drawdown
    or plunge) now holds and counts up `+0:07` until you tap **Done**.
    Because every earlier step advances exactly on time, that count-up is
    also, precisely, how far the whole brew is past its plan — which is what
    feeds planned vs actual in the log.
    **Trade-off accepted:** a slow Pour 1 still lets the app move on to Pour 2
    without you. Fewer taps was judged the better default; "Skip step" remains
    for leaving a step early.
    Implemented as `BrewTimerEngine.isOnFinalStep` (no per-step-type flag).
  - **Log the actual finish time** — the engine already tracks `totalElapsed`, and
    espresso already logs actual `shotSeconds`; extend that to all methods:
    add an actual-time field to the log and show **planned vs actual**.
- **Files:** `CoffeeGramsCore/.../Timer/BrewTimerEngine.swift` (already has
  `totalElapsed`), `Features/GuidedBrew/GuidedBrewView.swift` +
  `GuidedBrewViewModel.swift` (master clock + toggle + Done), reconcile with
  `EspressoShotView`; `Models/BrewLogEntry.swift`, `Persistence/BrewLogRecord.swift`,
  `Features/Log/LogDetailView.swift` + `LogView.swift` (new actual-time field).
- **AS BUILT (2026-07-29):**
  - **Core** — `BrewTimerEngine.isOnFinalStep`; new `BrewTimerPhase.overrunning`
    and `BrewTimerEvent.reachedTarget`, both reached only on the last step;
    `totalWallElapsed` master clock that runs through the final-step hold and
    stops only when paused (kept separate from `totalElapsed`, which still
    measures progress against the plan so the progress bar can't exceed 100%);
    `overrunInStep` (for a *manual* final step, which has no target time, every
    second counts); pause/resume from any live phase; and `finish()` to end a
    brew where it stands.
  - **App** — a "TOTAL m:ss" count-up readout under the step countdown; on the
    final step the big numeral becomes `+0:07` in gold (the `+` and the caption
    are the non-colour cues). Controls: **Done** on the final step, a
    **Pause/Resume** ⇄ **End Brew** row elsewhere, and "Skip step" as tertiary
    while a countdown runs. A `targetReached()` haptic marks the planned end.
  - **One button per outcome on the last step:** Done already ends the brew
    there, so "End Brew" is hidden beside it. "End Brew" is deliberately not
    also called "Done" — two "Done" buttons would have recreated the exact
    duplicate-label bug that item 2 above fixes.
  - **Log** — `plannedSeconds` + `actualSeconds` on `BrewLogEntry` and
    `BrewLogRecord` (both optional with nil defaults → lightweight SwiftData
    migration; pre-1.1 rows just omit the line). The log list shows
    "4:45 actual · 4:15 planned" and the detail screen adds Planned/Actual rows
    with a "+0:30 over plan" delta.
  - **Tests** — Core suite at 48 passing tests (intermediate auto-advance,
    final-step hold for both timed and manual last steps, master clock through
    holds and pauses, `finish()`); app suite adds master-clock,
    planned-vs-actual and End Brew coverage; the XCUITest brew→save→log flow
    passes. Debug + Release build warning-free.
- **Status:** ✅ **CONFIRMED for 1.1** (owner approved the design 2026-07-20).
- **⚠️ Manual test gate (this feature only):** the timer/clock + Start/Stop + Done
  buttons must pass the **owner's manual test in the simulator** before moving on.
  Build it → run in the simulator → owner tries the workflow and confirms they like
  it → only then proceed to the next section. Do not consider this item done on
  code/tests alone; it needs the owner's sign-off on the feel.
  - **Gate outcome:** the first build (soft targets on every hands-on step) was
    **rejected on feel** — too many taps. Reworked to auto-advance everything but
    the last step, rebuilt to the simulator, and the owner confirmed
    ("ok that's better"). ✅ Gate passed 2026-07-29. Worth noting the gate did
    its job: the tests were green on a design the owner didn't want.


## Decided: NO ads

Unchanged from 1.0 and not up for revisit — see
[`roadmap_future.md`](roadmap_future.md) for the full reasoning.

## Execution checklist

- [x] Branch off `main` (`release/1.1-fixes`) so Qodo reviews the PR.
- [x] Fix 1 — keypad dismissal.
- [x] Fix 2 — de-duplicate the start buttons.
- [x] Fix 3 — timer: master clock, final-step overrun, End Brew, planned vs actual.
- [x] Owner manual simulator gate on the timer.
- [x] All suites green (Core 48, app unit, XCUITest) + Debug/Release warning-free.
- [x] Bump `MARKETING_VERSION` to 1.1 and `CURRENT_PROJECT_VERSION` to 2.
- [ ] Push the branch, open the PR, drive Qodo findings to zero.
- [ ] "What's New" copy for the listing. **No new screenshots needed** — 1.1 is
      iPhone-only and the existing 1290×2796 set still matches the UI, apart
      from the guided-brew screen's new controls. Retake that one if it reads
      as stale.
- [ ] Merge → archive → TestFlight → submit (manual release).

## What's New (draft copy)

> **Fixes and a better brew timer.**
>
> • The number pad on the calculator now has a Done button, so it no longer
>   covers the screen.
> • Clearer buttons: "Set Up Brew" takes you to the timer, "Start Timer"
>   starts the clock.
> • The timer now shows total elapsed time for the whole brew, and counts up
>   if your last step runs long.
> • Your brew log now records how long a brew actually took, next to how long
>   it was planned to take.
