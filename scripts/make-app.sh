#!/bin/bash
# Assemble BHMac.app from the release build. No Xcode required.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --build-system native --product BHMacApp

APP=BHMac.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/BHMacApp "$APP/Contents/MacOS/BHMac"
cp scripts/Info.plist "$APP/Contents/Info.plist"

echo "Built $APP — run with: open $APP"
