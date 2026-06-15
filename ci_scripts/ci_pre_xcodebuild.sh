#!/bin/sh
set -e

echo "=== ci_pre_xcodebuild.sh: Forcing plugin trust defaults ==="
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidation -bool YES
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

defaults write com.apple.dt.xcodebuild IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.xcodebuild IDESkipPackagePluginFingerprintValidation -bool YES
defaults write -g IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write -g IDESkipPackagePluginFingerprintValidation -bool YES

defaults write com.apple.dt.xcodebuild IDESkipMacroFingerprintValidation -bool YES
defaults write -g IDESkipMacroFingerprintValidation -bool YES

echo "Defaults for com.apple.dt.Xcode (IDESkip):"
defaults read com.apple.dt.Xcode | grep IDESkip || true

echo "=== Generating Skip.env ==="
cat << EOF > ../Skip.env
PRODUCT_NAME = ${SKIP_PRODUCT_NAME}
PRODUCT_BUNDLE_IDENTIFIER = ${SKIP_BUNDLE_ID}
MARKETING_VERSION = ${SKIP_MARKETING_VERSION}
CURRENT_PROJECT_VERSION = ${SKIP_BUILD_NUMBER}
ANDROID_PACKAGE_NAME = ${SKIP_ANDROID_PACKAGE_NAME}
TEAM_ID = ${SKIP_TEAM_ID}
API_SERVER_URL = ${SKIP_API_SERVER_URL}
NEXT_PUBLIC_SUPABASE_URL = ${NEXT_PUBLIC_SUPABASE_URL}
NEXT_PUBLIC_SUPABASE_ANON_KEY = ${NEXT_PUBLIC_SUPABASE_ANON_KEY}
EOF
echo "Skip.env successfully generated!"
