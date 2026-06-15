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
PRODUCT_NAME = Audiobookphile
PRODUCT_BUNDLE_IDENTIFIER = club.foodshare.audiobookphile
MARKETING_VERSION = 0.0.1
CURRENT_PROJECT_VERSION = 1
ANDROID_PACKAGE_NAME = audiobookphile.module
TEAM_ID = DCKVD6LKYV
API_SERVER_URL = https://audiobookphile.vercel.app/api
NEXT_PUBLIC_SUPABASE_URL = ${NEXT_PUBLIC_SUPABASE_URL}
NEXT_PUBLIC_SUPABASE_ANON_KEY = ${NEXT_PUBLIC_SUPABASE_ANON_KEY}
EOF
echo "Skip.env successfully generated!"
