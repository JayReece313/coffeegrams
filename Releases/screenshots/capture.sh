#!/bin/bash
#
# Capture the App Store screenshots that a release invalidated.
#
# Drives the real app through XCUITest (CoffeeGramsUITests/ScreenshotCaptureTests
# .swift), pulls the full-resolution frames out of the result bundle, and fits
# them to the upload size for the target platform. Nothing capture-only is
# added to the app target, so what you shoot is the build you ship.
#
# Usage, from the repo root:
#   ./Releases/screenshots/capture.sh                  # all capture tests (iPhone)
#   ./Releases/screenshots/capture.sh 03-guided-timer  # just one (iPhone)
#   CG_PLATFORM=ipad ./Releases/screenshots/capture.sh  # all capture tests (iPad)
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."   # repo root, wherever it's called from

WANTED="${1:-}"
# iphone (default) or ipad. Each writes to its own subdirectory and its own
# upload size — Apple treats the two as separate screenshot sets, and an
# iPad-sized frame in the iPhone slot (or vice versa) gets rejected outright.
PLATFORM="${CG_PLATFORM:-iphone}"
case "$PLATFORM" in
    iphone) OUT_DIR="Releases/screenshots" ;;
    ipad)   OUT_DIR="Releases/screenshots/ipad" ;;
    *) echo "CG_PLATFORM must be iphone or ipad, got '$PLATFORM'" >&2; exit 2 ;;
esac
mkdir -p "$OUT_DIR"
WORK="$(mktemp -d)"
SIM=""

# Teardown runs on every exit path, not just the happy one: a status bar left
# pinned at 9:41 with a full battery would silently contaminate every later
# manual test and screenshot on that simulator.
cleanup() {
    if [ -n "$SIM" ]; then
        xcrun simctl status_bar "$SIM" clear 2>/dev/null || true
        xcrun simctl spawn "$SIM" launchctl unsetenv CG_CAPTURE 2>/dev/null || true
    fi
    rm -rf "$WORK"
    return 0
}
trap cleanup EXIT

# The upload size.
if [ "$PLATFORM" = ipad ]; then
    # 13" iPad Pro/Air (M-series) — required size per Apple's current
    # screenshot spec, and exactly what these simulators capture natively (no
    # fit-down actually changes anything here; sips still runs so a future
    # simulator with different native pixels doesn't silently upload wrong).
    WIDTH=2064
    HEIGHT=2752
else
    # Current Pro Max simulators capture larger (iPhone 17 Pro Max is
    # 1320×2868) and some ASC uploaders reject that, so we always fit down.
    WIDTH=1290
    HEIGHT=2796
fi

# --- Pick the simulator -------------------------------------------------------
# No device is hardcoded: the newest match is discovered from whatever is
# installed and resolved to a UDID, never a name — names repeat across installed
# runtimes, so a name alone can't say which device you mean. Version-sorted in
# python3 (ships with Xcode) because `sort -V` isn't dependable on a stock macOS
# sort.
#
# The default *family* is Pro Max on iPhone / 13-inch on iPad, and that part
# is not arbitrary: those are the sizes WIDTH/HEIGHT above assume, and a
# device of another family captures a different aspect ratio, which `sips -z`
# would then squash rather than letting the shot crop. Both are overridable
# for a machine that has something else installed:
#
#   CG_SIM_UDID=<udid>                     use exactly this simulator
#   CG_SIM_DEVICE='iPhone (\d+) Pro'       match a different iPhone family
#   CG_SIM_DEVICE='iPad Pro 11-inch \(M(\d+)\)'  match a different iPad family
#
# CG_SIM_DEVICE is a python regex matched with fullmatch, so it has to cover the
# device name end to end — 'iPhone .*Pro' will *not* match "iPhone 17 Pro Max".
# A capture group around just the model *number* (not any letter prefix, e.g.
# `M(\d+)` not `(M\d+)`) is what makes "newest wins" work — the sort keys on
# digits only, so a non-digit capture falls through to the runtime-version
# tiebreak for every device, silently discarding the model-number comparison.
#
if [ "$PLATFORM" = ipad ]; then
    DEFAULT_DEVICE_PATTERN='iPad Pro 13-inch \(M(\d+)\)'
else
    DEFAULT_DEVICE_PATTERN='iPhone (\d+) Pro Max'
fi
DEVICE_PATTERN="${CG_SIM_DEVICE:-$DEFAULT_DEVICE_PATTERN}"

if [ -n "${CG_SIM_UDID:-}" ]; then
    SIM="$CG_SIM_UDID"
else
    SIM=$(xcrun simctl list devices available --json | DEVICE_PATTERN="$DEVICE_PATTERN" python3 -c '
import json, os, re, sys
pattern = re.compile(os.environ["DEVICE_PATTERN"])
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    rm = re.search(r"iOS-([\d-]+)", runtime)          # iOS runtimes only
    if not rm:
        continue
    ver = tuple(int(n) for n in rm.group(1).split("-"))  # numeric, not string
    for dev in devices:
        dm = pattern.fullmatch(dev["name"])
        # Sort on any trailing number in the name (iPhone 17 > iPhone 9), then
        # on runtime, so "newest installed" wins without naming a device.
        if dm:
            digits = [int(g) for g in dm.groups() if g and g.isdigit()]
            key = (digits, ver)
            if best is None or key > best[0]:
                best = (key, dev)
print(best[1]["udid"] if best else "", end="")')
fi

if [ -z "$SIM" ]; then
    echo "no simulator matching /$DEVICE_PATTERN/ is installed." >&2
    echo "Add one in Xcode > Settings > Components, or set CG_SIM_DEVICE / CG_SIM_UDID." >&2
    if [ "$PLATFORM" = ipad ]; then
        echo "Installed iPads:" >&2
        xcrun simctl list devices available | grep -E "^\s+iPad" >&2 || true
    else
        echo "Installed iPhones:" >&2
        xcrun simctl list devices available | grep -E "^\s+iPhone" >&2 || true
    fi
    exit 1
fi
echo "▸ simulator $SIM"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
open -a Simulator

# The marketing status bar: 9:41, full bars, charged.
xcrun simctl status_bar "$SIM" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

# Switch the tests from asserting to shooting.
#
# This goes through the simulator's launchd rather than xcodebuild: the
# documented `TEST_RUNNER_<VAR>` build setting does *not* reach the test runner
# here (verified on Xcode 26.6, with and without parallel testing), whereas a
# variable set in the simulator's environment is inherited by every process it
# launches afterwards, the runner included.
xcrun simctl spawn "$SIM" launchctl setenv CG_CAPTURE 1

# --- Run the capture tests ----------------------------------------------------
ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests)
if [ -n "$WANTED" ]; then
    case "$WANTED" in
        01-home)         ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests/testCaptureHome) ;;
        02-calculator)   ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests/testCaptureCalculator) ;;
        03-guided-timer) ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests/testCaptureGuidedTimer) ;;
        04-paywall)      ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests/testCapturePaywall) ;;
        05-brew-log)     ONLY=(-only-testing:CoffeeGramsUITests/ScreenshotCaptureTests/testCaptureBrewLog) ;;
        *) echo "unknown screenshot '$WANTED' (try 01-home, 02-calculator, 03-guided-timer, 04-paywall, 05-brew-log)" >&2; exit 2 ;;
    esac
fi

echo "▸ running capture tests (Release)"
# -configuration Release: the scheme's TestAction is Debug, and a screenshot of
# a Debug build isn't a screenshot of what ships. Nothing in the app is behind
# `#if DEBUG` today, so the two render identically — but that's a fact about
# today, and a debug-only affordance added later would otherwise leak straight
# onto the App Store listing.
#
# ENABLE_TESTABILITY=YES because the unit-test target does `@testable import
# CoffeeGrams`, which Release turns off; xcodebuild builds every test target
# even when -only-testing narrows what runs, so without this the build fails
# before a single screenshot is taken. It relaxes cross-module optimisation,
# which no screenshot can observe.
#
# -parallel-testing-enabled NO so the run happens on the simulator we booted and
# pinned, rather than on a clone of it.
xcodebuild test \
    -project CoffeeGrams/CoffeeGrams.xcodeproj \
    -scheme CoffeeGrams \
    -configuration Release \
    -destination "platform=iOS Simulator,id=$SIM" \
    -resultBundlePath "$WORK/capture.xcresult" \
    -parallel-testing-enabled NO \
    "${ONLY[@]}" \
    ENABLE_TESTABILITY=YES \
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

echo "▸ done"   # the status bar and CG_CAPTURE are undone by the EXIT trap
