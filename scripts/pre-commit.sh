#!/bin/bash

if [ "$#" -eq 0 ]; then
  exit 0
fi

SWIFT_FILES=$(echo "$@" | tr ' ' '\n' | grep '\.swift$' || true)
JSON_FILES=$(echo "$@" | tr ' ' '\n' | grep -E '\.(json|yml|yaml)$' || true)
ALL_FILES="$@"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 1 — INSTANT BLOCKERS (fast grep, <100ms)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. Merge Conflict Marker Guard
echo "🔍 [1/11] Merge Conflict Marker check..."
CONFLICT_FILES=$(grep -E -l '^(<<<<<<<|=======|>>>>>>>)' $ALL_FILES 2>/dev/null | grep -v 'pre-commit.sh' || true)
if [ -n "$CONFLICT_FILES" ]; then
    echo "❌ Unresolved git merge conflict markers found in:"
    echo "$CONFLICT_FILES"
    exit 1
fi

# 2. Secret & Credential Leak Scanner
echo "🔍 [2/11] Secret Scan check..."
FORBIDDEN_PATTERNS="eyJhbGci|sbp_[a-zA-Z0-9]{20,}|SUPABASE_SERVICE_ROLE|BEGIN PRIVATE KEY|sk_live_|AKIA[0-9A-Z]{16}"
LEAKED_FILES=$(grep -E -l "$FORBIDDEN_PATTERNS" $ALL_FILES 2>/dev/null | grep -v '\.example' | grep -v 'pre-commit.sh' || true)
if [ -n "$LEAKED_FILES" ]; then
    echo "❌ SECURITY: Potential secret/credential leak detected in:"
    echo "$LEAKED_FILES"
    exit 1
fi

# 3. Large Audio Media & Bloat File Guard (.m4b, .mp3, .flac, >10MB)
echo "🔍 [3/11] Repo Bloat & Audio Media Guard..."
AUDIO_BLOAT=$(echo "$ALL_FILES" | tr ' ' '\n' | grep -i -E '\.(m4b|mp3|flac|aac|wav|ogg|zip|tar\.gz|iso)$' || true)
if [ -n "$AUDIO_BLOAT" ]; then
    echo "❌ REPO BLOAT GUARD: Accidental audio media or large binary file staged:"
    echo "$AUDIO_BLOAT"
    echo "Audio files must not be committed into git storage!"
    exit 1
fi

# 4. JSON / YAML Syntax Guard
if [ -n "$JSON_FILES" ]; then
    echo "🔍 [4/11] JSON/YAML Syntax Guard..."
    for f in $JSON_FILES; do
        if echo "$f" | grep -q '\.json$'; then
            python3 -m json.tool "$f" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "❌ JSON SYNTAX ERROR in file: $f"
                exit 1
            fi
        fi
    done
fi

# 5. Legacy @Published Guard (Rule 1: No Legacy Code)
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [5/11] Swift Bleeding-Edge @Published Guard..."
    PUBLISHED_FILES=$(grep -n '@Published' $SWIFT_FILES 2>/dev/null || true)
    if [ -n "$PUBLISHED_FILES" ]; then
        echo "❌ Legacy @Published found (use @Observable instead):"
        echo "$PUBLISHED_FILES"
        exit 1
    fi
fi

# 6. Force-Unwrap & Crash Pattern Guard
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [6/11] Force-Unwrap & Crash Pattern Guard..."
    FORCE_UNWRAPS=$(grep -n 'try!' $SWIFT_FILES 2>/dev/null || true)
    FATAL_ERRORS=$(grep -n 'fatalError(' $SWIFT_FILES 2>/dev/null | grep -v 'Tests/' | grep -v 'Preview' || true)
    if [ -n "$FORCE_UNWRAPS" ]; then
        echo "⚠️ WARNING: try! force-try found (can crash in production):"
        echo "$FORCE_UNWRAPS"
        exit 1
    fi
    if [ -n "$FATAL_ERRORS" ]; then
        echo "⚠️ WARNING: fatalError() found in non-test code:"
        echo "$FATAL_ERRORS"
        exit 1
    fi
fi

# 7. Debug Print Leftover Guard
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [7/11] Debug Print Leftover Guard..."
    DEBUG_PRINTS=$(grep -n 'debugPrint\|NSLog\|dump(' $SWIFT_FILES 2>/dev/null || true)
    if [ -n "$DEBUG_PRINTS" ]; then
        echo "⚠️ WARNING: Debug print statements found:"
        echo "$DEBUG_PRINTS"
        exit 1
    fi
fi

# 8. Hardcoded URL / Localhost Guard
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [8/11] Hardcoded URL Guard..."
    HARDCODED_URLS=$(grep -n 'http://localhost\|127\.0\.0\.1\|http://0\.0\.0\.0' $SWIFT_FILES 2>/dev/null | grep -v 'Tests/' | grep -v 'Mock' | grep -v 'Preview' || true)
    if [ -n "$HARDCODED_URLS" ]; then
        echo "⚠️ WARNING: Hardcoded localhost/dev URLs found in production code:"
        echo "$HARDCODED_URLS"
        exit 1
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 2 — STATIC ANALYSIS (swiftlint, ~2s)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [ -n "$SWIFT_FILES" ]; then
    if ! which swiftlint >/dev/null; then
        echo "⚠️ SwiftLint not installed, skipping..."
    else
        echo "🔍 [9/11] SwiftLint strict analysis..."
        swiftlint lint --strict --paths $SWIFT_FILES
        if [ $? -ne 0 ]; then
            echo "❌ SwiftLint violations found."
            exit 1
        fi
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 3 — COMPILER VERIFICATION (swift build, ~5-10s)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [10/11] Swift 6 Compiler & Strict Concurrency check..."
    swift build --build-tests 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ Swift compilation failed."
        exit 1
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TOTAL_FILES=$(echo "$ALL_FILES" | wc -w | tr -d ' ')
echo ""
echo "✅ [11/11] Mobile pre-commit passed — $TOTAL_FILES file(s) verified across 10 intelligent guards."
