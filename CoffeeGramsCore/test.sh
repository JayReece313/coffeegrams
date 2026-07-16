#!/usr/bin/env bash
#
# Run the CoffeeGramsCore test suite from the command line.
#
# WHY this script exists:
#   Swift Testing (the `import Testing` framework) ships inside the Command Line
#   Tools, but plain `swift test` doesn't add its framework/macro-plugin search
#   paths automatically — only full Xcode wires those up for you. Rather than
#   bake machine-specific `unsafeFlags` into Package.swift (which would pollute
#   the manifest and break the native Xcode build), we pass the paths here at
#   invocation time. Package.swift stays clean and portable; this script is just
#   for local/CI command-line runs.
#
# Usage:  ./test.sh            # run everything
#         ./test.sh --filter Calculator   # forward any extra args to swift test
set -euo pipefail

DEVDIR="$(xcode-select -p)"
FWPATH="$DEVDIR/Library/Developer/Frameworks"
PLUGIN="$DEVDIR/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"

if [[ ! -d "$FWPATH/Testing.framework" ]]; then
  echo "error: Swift Testing framework not found at $FWPATH" >&2
  echo "       Install the Xcode Command Line Tools (or full Xcode)." >&2
  exit 1
fi

exec swift test \
  -Xswiftc -F -Xswiftc "$FWPATH" \
  -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN" \
  -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
  -Xlinker -F -Xlinker "$FWPATH" \
  -Xlinker -rpath -Xlinker "$FWPATH" \
  "$@"
