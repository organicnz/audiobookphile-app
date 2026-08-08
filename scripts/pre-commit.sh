#!/bin/bash

if [ "$#" -eq 0 ]; then
  exit 0
fi

# Secret Scan Guard
echo "Running Secret Scan check..."
FORBIDDEN_PATTERNS="eyJh|eyJhbGci|sbp_[a-zA-Z0-9]{40}|BEGIN PRIVATE KEY|service_role"
LEAKED_FILES=$(grep -E -l "$FORBIDDEN_PATTERNS" "$@" 2>/dev/null | grep -v '\.example' | grep -v 'pre-commit.sh' || true)

if [ -n "$LEAKED_FILES" ]; then
    echo "❌ SECURITY ALERT: Potential secret / credential leak detected in:"
    echo "$LEAKED_FILES"
    echo "Please remove hardcoded secrets or service role keys before committing!"
    exit 1
fi

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

echo "Running Swift compilation pre-commit check..."
swift build --build-tests
if [ $? -ne 0 ]; then
    echo "❌ Swift compilation failed. Please fix compiler errors before committing."
    exit 1
fi

echo "✅ Pre-commit verification passed cleanly!"
