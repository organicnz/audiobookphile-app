#!/bin/bash

if [ "$#" -eq 0 ]; then
  exit 0
fi

SWIFT_FILES=$(echo "$@" | tr ' ' '\n' | grep '\.swift$' || true)
if [ -z "$SWIFT_FILES" ]; then
  exit 0
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 1 — INSTANT BLOCKERS (fast grep, <100ms)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. Merge Conflict Marker Guard
echo "🔍 [1/9] Merge Conflict Marker check..."
CONFLICT_FILES=$(grep -E -l '^(<<<<<<<|=======|>>>>>>>)' $SWIFT_FILES 2>/dev/null || true)
if [ -n "$CONFLICT_FILES" ]; then
    echo "❌ Unresolved git merge conflict markers found in:"
    echo "$CONFLICT_FILES"
    exit 1
fi

# 2. Secret & Credential Leak Scanner
echo "🔍 [2/9] Secret Scan check..."
FORBIDDEN_PATTERNS="eyJhbGci|sbp_[a-zA-Z0-9]{20,}|SUPABASE_SERVICE_ROLE|BEGIN PRIVATE KEY|sk_live_|AKIA[0-9A-Z]{16}"
LEAKED_FILES=$(grep -E -l "$FORBIDDEN_PATTERNS" $SWIFT_FILES 2>/dev/null || true)
if [ -n "$LEAKED_FILES" ]; then
    echo "❌ SECURITY: Potential secret/credential leak detected in:"
    echo "$LEAKED_FILES"
    exit 1
fi

# 3. Legacy @Published Guard (Rule 1: No Legacy Code)
echo "🔍 [3/9] Swift Bleeding-Edge @Published Guard..."
PUBLISHED_FILES=$(grep -n '@Published' $SWIFT_FILES 2>/dev/null || true)
if [ -n "$PUBLISHED_FILES" ]; then
    echo "❌ Legacy @Published found (use @Observable instead):"
    echo "$PUBLISHED_FILES"
    exit 1
fi

# 4. Force-Unwrap & Crash Pattern Guard
echo "🔍 [4/9] Force-Unwrap & Crash Pattern Guard..."
FORCE_UNWRAPS=$(grep -n 'try!' $SWIFT_FILES 2>/dev/null || true)
FATAL_ERRORS=$(grep -n 'fatalError(' $SWIFT_FILES 2>/dev/null | grep -v 'Tests/' | grep -v 'Preview' || true)
if [ -n "$FORCE_UNWRAPS" ]; then
    echo "⚠️  WARNING: try! force-try found (can crash in production):"
    echo "$FORCE_UNWRAPS"
    echo "Use do/catch or try? instead."
    exit 1
fi
if [ -n "$FATAL_ERRORS" ]; then
    echo "⚠️  WARNING: fatalError() found in non-test code:"
    echo "$FATAL_ERRORS"
    echo "Use assertionFailure() or graceful error handling instead."
    exit 1
fi

# 5. Debug Print Leftover Guard
echo "🔍 [5/9] Debug Print Leftover Guard..."
DEBUG_PRINTS=$(grep -n 'debugPrint\|NSLog\|dump(' $SWIFT_FILES 2>/dev/null || true)
if [ -n "$DEBUG_PRINTS" ]; then
    echo "⚠️  WARNING: Debug print statements found (use structured logging):"
    echo "$DEBUG_PRINTS"
    echo "Remove debugPrint/NSLog/dump before committing."
    exit 1
fi

# 6. Hardcoded URL / Localhost Guard
echo "🔍 [6/9] Hardcoded URL Guard..."
HARDCODED_URLS=$(grep -n 'http://localhost\|127\.0\.0\.1\|http://0\.0\.0\.0' $SWIFT_FILES 2>/dev/null | grep -v 'Tests/' | grep -v 'Mock' | grep -v 'Preview' || true)
if [ -n "$HARDCODED_URLS" ]; then
    echo "⚠️  WARNING: Hardcoded localhost/dev URLs found in production code:"
    echo "$HARDCODED_URLS"
    echo "Use environment-based configuration instead."
    exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 2 — STATIC ANALYSIS (swiftlint, ~2s)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if ! which swiftlint >/dev/null; then
    echo "⚠️ SwiftLint not installed, skipping..."
else
    echo "🔍 [7/9] SwiftLint strict analysis..."
    swiftlint lint --strict --paths $SWIFT_FILES
    if [ $? -ne 0 ]; then
        echo "❌ SwiftLint violations found."
        exit 1
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 3 — COMPILER VERIFICATION (swift build, ~5-10s)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🔍 [8/9] Swift 6 Compiler & Strict Concurrency check..."
swift build --build-tests 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Swift compilation failed."
    exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 4 — SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TOTAL_FILES=$(echo "$SWIFT_FILES" | wc -w | tr -d ' ')
echo ""
echo "✅ [9/9] Mobile pre-commit passed — $TOTAL_FILES file(s) verified across 8 intelligent guards."
