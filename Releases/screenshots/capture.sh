#!/bin/bash
#
# Capture the App Store screenshots that a release invalidated.
#
# Drives the real app through XCUITest (CoffeeGramsUITests/ScreenshotCaptureTests
# .swift), pulls the full-resolution frames out of the result bundle, and fits
# them to the 1290×2796 upload size. Nothing capture-only is added to the app
# target, so what you shoot is the build you ship.
#
# Usage, from the repo root:
#   ./Releases/screenshots/capture.sh                  # all capture tests
#   ./Releases/screenshots/capture.sh 03-guided-timer  # just one
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."   # repo root, wherever it's called from

WANTED="${1:-}"
OUT_DIR="Releases/screenshots"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The upload size. Current Pro Max simulators capture larger (iPhone 17 Pro Max
# is 1320×2868) and some ASC uploaders reject that, so we always fit down.
WIDTH=1290
HEIGHT=2796

# --- Pick the simulator -------------------------------------------------------
# Resolved to a UDID, never a name: names repeat across installed runtimes, so a
# name alone can't say which device you mean. Version-sorted in python3 (ships
# with Xcode) because `sort -V` isn't dependable on a stock macOS sort.
SIM=$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    rm = re.search(r"iOS-([\d-]+)", runtime)          # iOS runtimes only
    if not rm:
        continue
    ver = tuple(int(n) for n in rm.group(1).split("-"))  # numeric, not string
    for dev in devices:
        dm = re.fullmatch(r"iPhone (\d+) Pro Max", dev["name"])
        if dm:
            key = (int(dm.group(1)), ver)
            if best is None or key > best[0]:
                best = (key, dev)
print(best[1]["udid"] if best else "", end="")')

: "${SIM:?no iPhone Pro Max simulator installed — add one in Xcode > Settings > Components}"
echo "▸ simulator $SIM"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
open -a Simulator

# The marketing status bar: 9:41, full bars, charged.
xcrun simctl status_bar "$SIM" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

# --- Run the capture tests ----------------------------------------------------
ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests)
if [ -n "$WANTED" ]; then
    case "$WANTED" in
        02-calculator)   ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests/testCaptureCalculator) ;;
        03-guided-timer) ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests/testCaptureGuidedTimer) ;;
        *) echo "unknown screenshot '$WANTED' (try 02-calculator or 03-guided-timer)" >&2; exit 2 ;;
    esac
fi

echo "▸ running capture tests"
xcodebuild test \
    -project CoffeeGrams/CoffeeGrams.xcodeproj \
    -scheme CoffeeGrams \
    -destination "platform=iOS Simulator,id=$SIM" \
    -resultBundlePath "$WORK/capture.xcresult" \
    "${ONLY[@]}" \
    > "$WORK/xcodebuild.log" 2>&1 \
  || { echo "capture run failed — last 40 lines:" >&2; tail -40 "$WORK/xcodebuild.log" >&2; exit 1; }

# --- Pull the frames out of the result bundle ---------------------------------
xcrun xcresulttool export attachments \
    --path "$WORK/capture.xcresult" \
    --output-path "$WORK/attachments" >/dev/null

# The exported filenames carry a generated suffix ("02-calculator_0_<uuid>.png"),
# so map each one back to the bare attachment name the test set and write it
# straight over the tracked asset — there's then no way to produce a correct
# image and still upload the stale one by mistake.
python3 - "$WORK/attachments" "$OUT_DIR" > "$WORK/written" <<'PY'
import json, pathlib, shutil, sys

src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
manifest = json.loads((src / "manifest.json").read_text())

written = set()
for test in manifest:
    for att in test.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or att.get("name") or ""
        stem = pathlib.Path(name).stem.split("_")[0]   # drop the "_0_<uuid>" suffix
        if not stem[:1].isdigit():                     # ignore XCTest's own extras
            continue
        target = dst / f"{stem}.png"
        shutil.copyfile(src / att["exportedFileName"], target)
        written.add(str(target))

if not written:
    sys.exit("no screenshot attachments found in the result bundle")
print("\n".join(sorted(written)))
PY

# --- Fit to the upload size and verify ----------------------------------------
# Only the files this run actually produced, so a partial run never touches the
# shots it didn't retake.
while IFS= read -r shot; do
    [ -n "$shot" ] || continue
    sips -z "$HEIGHT" "$WIDTH" "$shot" >/dev/null
    dims=$(sips -g pixelWidth -g pixelHeight "$shot" | awk '/pixel/{printf "%s ", $2}')
    echo "▸ $(basename "$shot"): ${dims% }"
    [ "$dims" = "$WIDTH $HEIGHT " ] || { echo "  ✗ expected $WIDTH $HEIGHT" >&2; exit 1; }
done < "$WORK/written"

# Best-effort teardown: xcodebuild runs the tests on a clone and may leave the
# original shut down, in which case there's no status bar left to clear.
xcrun simctl status_bar "$SIM" clear 2>/dev/null || true
echo "▸ done"
