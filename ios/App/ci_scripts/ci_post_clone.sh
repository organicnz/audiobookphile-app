#!/bin/sh

# Xcode Cloud post-clone script
# This runs after the repository is cloned

set -e

echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

echo "Installing dependencies with Bun..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
bun install

echo "Building web assets..."
bun run generate

echo "Syncing Capacitor..."
bunx cap sync ios

echo "Installing CocoaPods..."
cd "$CI_PRIMARY_REPOSITORY_PATH/ios/App"
pod install

echo "Post-clone script completed successfully"
