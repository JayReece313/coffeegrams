# App Store screenshots — v1.0

Ready to upload to App Store Connect at **1290 × 2796** (the canonical 6.9"
display size — iPhone 16 Pro Max) with a clean 9:41 status bar. (Captured at
1320 × 2868 on iPhone 17 Pro Max, then fit to 1290 × 2796 since some ASC
uploaders reject the newer 1320 × 2868.)

| # | File | Screen |
|---|------|--------|
| 1 | `01-home.png` | Home — branded logo lockup + method list with Pro locks |
| 2 | `02-calculator.png` | Calculator — French Press, dose → water readout |
| 3 | `03-guided-timer.png` | Guided brew — running countdown with step list |
| 4 | `04-paywall.png` | CoffeeGrams Pro — "Unlock Everything · $4.99" |
| 5 | `05-brew-log.png` | Brew log — rated brews with notes |

**Upload order:** in ASC, drag them in 1→5; the first is the lead/hero image.

**Note:** these are raw device frames (no marketing text overlays), which Apple
accepts. Screenshot #4 (paywall) also works as the review screenshot for the IAP.

*Regenerating:* these were produced by a temporary in-app harness (a `CG_SHOT`
env switch) that was removed after capture. To recreate, re-add the harness,
build for the 6.9" sim, and run `simctl launch` with `SIMCTL_CHILD_CG_SHOT` set
to `home`/`calc`/`guided`/`paywall`/`log`.
