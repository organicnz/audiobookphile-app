#!/bin/sh

# Xcode Cloud post-clone script
# This runs after the repository is cloned

set -e

echo "Installing Node.js via Homebrew..."
brew install node

echo "Installing Node.js dependencies..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
npm install --legacy-peer-deps

echo "Building web assets..."
npm run generate

echo "Syncing Capacitor..."
npx cap sync ios

echo "Installing CocoaPods..."
cd "$CI_PRIMARY_REPOSITORY_PATH/ios/App"
pod install

echo "Post-clone script completed successfully"
