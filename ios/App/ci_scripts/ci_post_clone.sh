#!/bin/zsh

# Xcode Cloud Post-Clone Script (Deeply Refactored)
# Exit immediately if any command fails, or if an uninitialized variable is used
set -euo pipefail

# Helper functions for structured and colorful CI logging
log_info() {
    echo "\n🔵 \033[1;34m[CI INFO]\033[0m $1"
}

log_success() {
    echo "🟢 \033[1;32m[CI SUCCESS]\033[0m $1\n"
}

log_error() {
    echo "🔴 \033[1;31m[CI ERROR]\033[0m $1\n"
}

# 1. Environment Verification & Node.js Installation
log_info "Verifying Node.js environment..."
if ! command -v node &> /dev/null; then
    log_info "Node.js not found. Installing via Homebrew..."
    brew install node
else
    log_success "Node.js is already installed: $(node -v)"
fi

# 2. Bun Installation
log_info "Verifying Bun installation..."
if ! command -v bun &> /dev/null; then
    log_info "Bun not found. Installing..."
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
else
    log_success "Bun is already installed: $(bun -v)"
fi

# Explicitly ensure Bun PATH variables are registered in this shell session
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# 3. Dependency Installation
log_info "Installing dependencies with Bun..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
bun install --frozen-lockfile

# 4. Compile Web Assets
log_info "Compiling Nuxt static assets..."
bun run generate

# 5. Capacitor Sync
log_info "Syncing web assets to native iOS project..."
bunx cap sync ios

# 6. CocoaPods Setup
log_info "Installing CocoaPods native dependencies..."
cd "$CI_PRIMARY_REPOSITORY_PATH/ios/App"
pod install

# 7. Grant execution permissions on all target support framework/resources scripts
log_info "Granting execution permissions on dynamically generated CocoaPods scripts..."
chmod -R +x "$CI_PRIMARY_REPOSITORY_PATH/ios/App/Pods/Target Support Files" || true

log_success "Xcode Cloud Post-Clone script completed successfully!"
