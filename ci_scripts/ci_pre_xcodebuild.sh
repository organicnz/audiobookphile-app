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
cat << 'EOF' > ../Skip.env
PRODUCT_NAME = Audiobookphile
PRODUCT_BUNDLE_IDENTIFIER = club.foodshare.audiobookphile
MARKETING_VERSION = 0.0.1
CURRENT_PROJECT_VERSION = 1
ANDROID_PACKAGE_NAME = audiobookphile.module
TEAM_ID = DCKVD6LKYV
API_SERVER_URL = https://audiobookphile.vercel.app/api
NEXT_PUBLIC_SUPABASE_URL = https://iambzzclljayqdxkeepy.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhbWJ6emNsbGpheXFkeGtlZXB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2NzI0MjcsImV4cCI6MjA5MzI0ODQyN30.GqEkaYrkCSNgO89ZqtIgJ28TNI0QfoLrPzW1zCj8st8
EOF
echo "Skip.env successfully generated!"
