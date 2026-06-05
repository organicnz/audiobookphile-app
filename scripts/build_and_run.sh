#!/bin/bash
set -e

PROJECT_DIR="/Users/organic/dev/work/audiobookshelf/audiobookphile-app"
SIMULATOR_ID="CC7BF58A-218E-4EC6-A084-F673841B51E3"
APP_BUNDLE_ID="nz.organic.audiobookphile"
WORKSPACE="$PROJECT_DIR/Project.xcworkspace"
SCHEME="Audiobookphile App"
DERIVED_DATA="$PROJECT_DIR/DerivedData"

echo "=== Step 1: Clean DerivedData ==="
rm -rf "$DERIVED_DATA"

echo "=== Step 2: Build Audiobookphile App (using generic simulator destination to bypass hang) ==="
# We use "generic/platform=iOS Simulator" to prevent xcodebuild from querying the live simulator daemon
# which gets stuck in this headless sandbox environment.
xcodebuild build \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED_DATA" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  SKIP_ZERO=true | grep -E "^(Build|Compile|Link|error:|warning:|✓|✗|\*\*)" || true

echo "=== Step 3: Find App Bundle ==="
APP_BUNDLE_PATH=$(find "$DERIVED_DATA/Build/Products" -name "Audiobookphile.app" -type d | head -n 1)

if [ -z "$APP_BUNDLE_PATH" ]; then
    echo "Error: Could not find Audiobookphile.app in DerivedData!"
    exit 1
fi
echo "Found App Bundle at: $APP_BUNDLE_PATH"

echo "=== Step 4: Boot Simulator (if not already booted) ==="
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true

echo "=== Step 5: Install App to Simulator ==="
xcrun simctl install "$SIMULATOR_ID" "$APP_BUNDLE_PATH"

echo "=== Step 6: Launch App ==="
xcrun simctl launch "$SIMULATOR_ID" "$APP_BUNDLE_ID"

echo "=== Build & Run Complete ==="
