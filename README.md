# CoffeeGrams

**Dial in every cup by the gram.** A native iOS coffee app: dose-and-ratio
calculators and guided brew timers for six methods, with a brew log that records
what you actually did.

On the App Store as **CoffeeGrams: Brew Calculator** · by JR Labs LLC · bundle
`com.jrlabapps.CoffeeGrams` ·
[site](https://jayreece313.github.io/coffeegrams/)

| | |
|---|---|
| **Live** | **1.0** — released 2026-07-29 |
| **In review** | **1.1** — submitted 2026-08-04, manual release |

## What it does

- **Calculators** — dose → water or water → dose, with a per-method ratio range.
- **Guided timers** — bloom, pours, steep, plunge; per-step countdown plus a
  running total that counts *up* if your last step overruns.
- **Brew log** — every saved brew with its rating, notes, and planned vs actual
  duration.
- **Six methods** — French Press is free; V60, Chemex, AeroPress, Espresso and
  Cold Brew unlock with a one-time **$4.99** Pro purchase
  (`com.jrlabapps.coffeegrams.pro`).

No accounts, no ads, no third-party SDKs, no analytics — the App Privacy label
is **Data Not Collected**, and it stays that way.

## Requirements

- **Xcode 26+**, Swift 6 (strict concurrency)
- The **CoffeeGrams app target deploys to iOS 17.6** — that's the minimum the
  shipped app supports
- `CoffeeGramsCore` declares **iOS 17 / macOS 14**. The macOS platform is what
  lets its suite run on the Mac from the command line, with no simulator

> **Heads-up on a real inconsistency:** the *project-level* setting and the
> `CoffeeGramsTests` target are both at **iOS 26.5**, above the app's own 17.6.
> The app target's setting is the one that governs what ships, so the store
> requirement is 17.6 — but it does mean the test targets can't run against a
> simulator on the app's minimum OS. Worth reconciling deliberately (either
> lower the test targets to 17.6, or raise the app and accept dropping iOS
> 17–25 devices). Left alone here because it's a product decision, and 1.1 is
> in App Store review as built.

## Build and run

```sh
open CoffeeGrams/CoffeeGrams.xcodeproj
```

Pick a simulator from the toolbar and press **⌘R**. There is no `.xcworkspace`
and no package resolution step — `CoffeeGramsCore` is a local package the
project already references.

From the command line:

```sh
# Build (no specific device needed)
xcodebuild build -scheme CoffeeGrams -configuration Release \
  -project CoffeeGrams/CoffeeGrams.xcodeproj \
  -destination 'generic/platform=iOS Simulator'
```

## Test

```sh
# Pure logic — runs on the Mac in milliseconds, no simulator
(cd CoffeeGramsCore && swift test)

# Whole app — unit + UI, needs a booted simulator
(cd CoffeeGrams && xcodebuild test -scheme CoffeeGrams \
  -destination 'platform=iOS Simulator,name=<latest available iPhone>')
```

Don't hardcode a simulator: list what's installed with
`xcrun simctl list devices available` and target the newest iPhone. Full
strategy in [`testing.md`](testing.md).

---

## How to work in here

Written for a Claude Code session that has never seen this repo.

### How to start

Open a session pointed at this directory. Read this section first, then
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the codebase map. If the task is a
release, [`Releases/submission_1.1.md`](Releases/submission_1.1.md) is the
as-built runbook and supersedes any general advice about App Store Connect.

**One session per task or milestone** — long multi-day sessions at high context
are what made the 1.0 build expensive. Start fresh per unit of work.

### The rules

- **Never push to `main`.** Every push goes to a new, descriptively named branch,
  then a PR. Branch per *unit of work*, not per commit — several commits on one
  branch is fine.
- **Only commit or push when asked.** Keep local `main` clean and matching the
  remote.
- **Qodo reviews every push.** Drive findings to zero before merging. One known
  exception: **rule 2205425** falsely reports the versioned submission runbook as
  missing — it infers absence from `release_<version>.md`'s header instead of
  checking the file tree, so no repo edit can satisfy it. Dismiss it.
- **All suites green and Debug/Release warning-free** before a milestone is done.
- **TDD-leaning:** every model, view model, and service ships with tests.

### Where things live

| Path | What it is | When to edit |
|---|---|---|
| `CoffeeGramsCore/` | Pure Swift package — models, calculator, timeline builder, timer engine. **No UI imports.** | Any brewing logic or number. Add tests in the same commit |
| `CoffeeGrams/CoffeeGrams/` | The SwiftUI app — thin shell over the package | Screens, view models, platform adapters |
| `CoffeeGrams/CoffeeGrams/Platform/` | Ports & adapters: clock, notifications, haptics, purchases, diagnostics | Adding a side effect. It gets a protocol + a live adapter + a test double |
| `CoffeeGrams/CoffeeGramsTests/` | App unit tests (Swift Testing) | Alongside any app change |
| `CoffeeGrams/CoffeeGramsUITests/` | XCUITest flows, plus the screenshot harness | End-to-end flows; the strings the store screenshots depend on |
| `Releases/` | Per-version runbooks, the roadmap backlog, store screenshots | Shipping a version |
| `docs/` | The GitHub Pages site — privacy policy, support, marketing page | Changing anything Apple links to. **Public** |
| `coffeegrams_logo/` | CoreGraphics source for the logo and app icon | Brand changes |
| `ARCHITECTURE.md` · `DESIGN.md` · `testing.md` | Codebase map (Mermaid), palette and design rules, test strategy | Whenever the thing they describe changes |

### The main workflows

**Run everything before calling a milestone done:**

```sh
(cd CoffeeGramsCore && swift test)                       # 49 tests, 4 suites
(cd CoffeeGrams && xcodebuild test -scheme CoffeeGrams \
   -destination 'platform=iOS Simulator,name=<latest available iPhone>')
(cd CoffeeGrams && xcodebuild build -scheme CoffeeGrams -configuration Release \
   -destination 'generic/platform=iOS Simulator')
```

**Recapture App Store screenshots** (after any UI change that a listing image
shows):

```sh
./Releases/screenshots/capture.sh                  # every scripted shot
./Releases/screenshots/capture.sh 03-guided-timer  # just one
```

It discovers the newest iPhone Pro Max simulator by UDID, pins the status bar to
9:41, builds **Release**, drives the real UI from `ScreenshotCaptureTests.swift`,
and writes verified 1290×2796 files over the tracked assets. Never add
capture-only code to the app target — that was the 1.0 approach and it can reach
a shipping binary. Details in
[`Releases/screenshots/README.md`](Releases/screenshots/README.md).

### Invariants that must stay in sync

These are the cross-file rules that reviewers and Apple keep catching:

- **Store screenshots must match the shipped UI.** A release that renames a
  button can stale a listing image — this nearly shipped in 1.1, when
  "Start Brew" became "Set Up Brew" and the runbook had only flagged a different
  screenshot. `ScreenshotCaptureTests` now asserts the strings it photographs, so
  drift fails a test. **Audit every screenshot against the code each release**,
  not against the last release's notes.
- **`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`** must be consistent across
  all build configs, and the build number must exceed anything already uploaded
  to App Store Connect.
- **The IAP product ID** in `Platform/PurchaseProvider.swift` must match App
  Store Connect exactly (`com.jrlabapps.coffeegrams.pro`).
- **Privacy and support URLs** in the ASC listing must match what `docs/`
  actually publishes.
- **`ARCHITECTURE.md`** is mirrored into the private `Summary` repo as
  `CoffeeGrams_ARCHITECTURE.md` — regenerate the copy when this one changes.
- **No third-party SDKs.** Adding one changes the App Privacy label and breaks
  the app's central privacy claim.

### Status — what's next

- **1.1 is in App Store review**, submitted 2026-08-04 as a single review item,
  manual release. When approved, someone must click **Release This Version** in
  App Store Connect — it will not go live on its own.
- **Two PRs are open and deliberately unmerged** until that outcome is known:
  the AS-BUILT runbook here, and the 1.1 retrospective in the private `Summary`
  repo. Both need the real approval/release dates before merging.
- **1.2 is iPad support**, plus whatever else is in
  [`Releases/roadmap_future.md`](Releases/roadmap_future.md) — iCloud sync and
  custom app icons are parked there. Before that release PR, fix Qodo rule
  2205425 cloud-side so the false positive stops firing.

Don't redo any of the above — 1.0 shipped 2026-07-29 and 1.1 is finished and
submitted. The repo itself has no outstanding work.

---

## Documentation

| Doc | What's in it |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Codebase map with Mermaid diagrams — layers, user flow, tests |
| [`DESIGN.md`](DESIGN.md) | Palette, the 60-30-10 rule, brand direction |
| [`testing.md`](testing.md) | Unit / integration / system / regression strategy and how to run each |
| [`Releases/submission_1.0.md`](Releases/submission_1.0.md) | As-built first-submission runbook — signing, App ID, IAP, every ASC page |
| [`Releases/submission_1.1.md`](Releases/submission_1.1.md) | As-built runbook for an *update*, which is a shorter and different flow |
| [`Releases/roadmap_future.md`](Releases/roadmap_future.md) | Backlog beyond 1.1 |
| [`CoffeeGramsCore/README.md`](CoffeeGramsCore/README.md) | Why the logic lives in its own package, and its layout |

## License

See [`LICENSE`](LICENSE). The repo is public so GitHub Pages can host the
privacy policy and support pages Apple requires.
