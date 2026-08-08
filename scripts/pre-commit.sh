#!/bin/bash

if [ "$#" -eq 0 ]; then
  exit 0
fi

# 1. Merge Conflict Marker Guard
echo "Running Merge Conflict Marker check..."
CONFLICT_FILES=$(grep -E -l '^(<<<<<<<|=======|>>>>>>>)' "$@" 2>/dev/null | grep -v 'pre-commit.sh' || true)
if [ -n "$CONFLICT_FILES" ]; then
    echo "❌ ERROR: Unresolved git merge conflict markers found in:"
    echo "$CONFLICT_FILES"
    echo "Please resolve conflict markers (<<<<<<< HEAD, =======, >>>>>>>) before committing!"
    exit 1
fi

# 2. Secret Scan Guard
echo "Running Secret Scan check..."
FORBIDDEN_PATTERNS="eyJh|eyJhbGci|sbp_[a-zA-Z0-9]{40}|BEGIN PRIVATE KEY|service_role"
LEAKED_FILES=$(grep -E -l "$FORBIDDEN_PATTERNS" "$@" 2>/dev/null | grep -v '\.example' | grep -v 'pre-commit.sh' || true)
if [ -n "$LEAKED_FILES" ]; then
    echo "❌ SECURITY ALERT: Potential secret / credential leak detected in:"
    echo "$LEAKED_FILES"
    echo "Please remove hardcoded secrets or service role keys before committing!"
    exit 1
fi

# 3. Swift Bleeding-Edge Guard (No legacy @Published)
echo "Running Swift Bleeding-Edge Rule Guard..."
PUBLISHED_FILES=$(grep -E -l '@Published' "$@" 2>/dev/null | grep '\.swift$' || true)
if [ -n "$PUBLISHED_FILES" ]; then
    echo "⚠️ WARNING: Legacy @Published macro found in modern Swift code:"
    echo "$PUBLISHED_FILES"
    echo "Rule 1 Violation: Use modern @Observable / @State instead of @Published."
    exit 1
fi

# 4. SwiftLint
if ! which swiftlint >/dev/null; then
    echo "⚠️ warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
    exit 0
fi

echo "Running SwiftLint on staged files..."
swiftlint lint --strict --paths "$@"
if [ $? -ne 0 ]; then
    echo "❌ SwiftLint failed. Please fix violations before committing."
    exit 1
fi

# 5. Swift Compilation Pre-Check
echo "Running Swift compilation pre-commit check..."
swift build --build-tests
if [ $? -ne 0 ]; then
    echo "❌ Swift compilation failed. Please fix compiler errors before committing."
    exit 1
fi

echo "✅ Mobile pre-commit verification passed cleanly!"
