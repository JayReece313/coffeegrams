# App Store screenshots — v1.1

Ready to upload to App Store Connect at **1290 × 2796** (the canonical 6.9"
display size — iPhone 16 Pro Max) with a clean 9:41 status bar. (Captured at
1320 × 2868 on iPhone 17 Pro Max, then fit to 1290 × 2796 since some ASC
uploaders reject the newer 1320 × 2868.)

| # | File | Screen |
|---|------|--------|
| 1 | `01-home.png` | Home — branded logo lockup + method list with Pro locks |
| 2 | `02-calculator.png` | Calculator — French Press, dose → water readout *(recaptured for 1.1)* |
| 3 | `03-guided-timer.png` | Guided brew — running countdown, TOTAL count-up, step list *(recaptured for 1.1)* |
| 4 | `04-paywall.png` | CoffeeGrams Pro — "Unlock Everything · $4.99" |
| 5 | `05-brew-log.png` | Brew log — rated brews with notes |

**Upload order:** in ASC, drag them in 1→5; the first is the lead/hero image.

**Note:** these are raw device frames (no marketing text overlays), which Apple
accepts. Screenshot #4 (paywall) also works as the review screenshot for the IAP.

## Regenerating

```sh
./capture.sh                  # from anywhere; both scripted shots
./capture.sh 03-guided-timer  # just one
```

`capture.sh` discovers the newest installed iPhone Pro Max simulator by UDID,
pins the status bar to 9:41, drives the real app via
`CoffeeGramsUITests/ScreenshotCaptureTests.swift`, pulls the frames out of the
result bundle, fits them to 1290×2796 and writes them straight over the tracked
files here.

**Currently scripted:** `02-calculator`, `03-guided-timer`.
**Still manual:** `01-home`, `04-paywall`, `05-brew-log` — `05` needs a
populated log and `04` a purchase sheet, neither of which the UI tests set up
yet. Add a test to `ScreenshotCaptureTests` when one of them next needs a
refresh.

*History:* the 1.0 set came from a temporary `CG_SHOT` switch inside the **app**
target that was added for a capture and deleted afterwards. That approach is
retired — capture-only code should never be able to reach a shipping build.
