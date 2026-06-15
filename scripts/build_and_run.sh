#!/bin/bash
set -e

PROJECT_DIR="${ABP_PROJECT_DIR:?Set ABP_PROJECT_DIR to your local project path}"
SIMULATOR_ID="${ABP_SIMULATOR_ID:?Set ABP_SIMULATOR_ID to your target simulator UDID}"
APP_BUNDLE_ID="${ABP_BUNDLE_ID:?Set ABP_BUNDLE_ID to your app bundle identifier}"
WORKSPACE="$PROJECT_DIR/Project.xcworkspace"
SCHEME="Audiobookphile App"
DERIVED_DATA="$PROJECT_DIR/DerivedData"

echo "=== Step 1: Clean DerivedData ==="
# rm -rf "$DERIVED_DATA" # Commented out because offline environments need the SPM cache!

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
