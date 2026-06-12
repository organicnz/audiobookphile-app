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
