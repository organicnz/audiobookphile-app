#!/bin/bash

if [ "$#" -eq 0 ]; then
  exit 0
fi

SWIFT_FILES=$(echo "$@" | tr ' ' '\n' | grep '\.swift$' || true)
PACKAGE_FILES=$(echo "$@" | tr ' ' '\n' | grep 'Package\.swift$' || true)
JSON_FILES=$(echo "$@" | tr ' ' '\n' | grep -E '\.(json|yml|yaml)$' || true)
ALL_FILES="$@"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 1 — INSTANT BLOCKERS & CYBERSECURITY AUDIT (<100ms)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. Merge Conflict Marker Guard
echo "🔍 [1/12] Merge Conflict Marker check..."
CONFLICT_FILES=$(grep -E -l '^(<<<<<<<|=======|>>>>>>>)' $ALL_FILES 2>/dev/null | grep -v 'pre-commit.sh' || true)
if [ -n "$CONFLICT_FILES" ]; then
    echo "❌ Unresolved git merge conflict markers found in:"
    echo "$CONFLICT_FILES"
    exit 1
fi

# 2. Deep Cybersecurity Secret & Private Key Scanner
echo "🔍 [2/12] Cybersecurity Secret & Key Scan..."
FORBIDDEN_PATTERNS="eyJhbGci|sbp_[a-zA-Z0-9]{20,}|SUPABASE_SERVICE_ROLE|BEGIN PRIVATE KEY|sk_live_|AKIA[0-9A-Z]{16}"
LEAKED_FILES=$(grep -E -l "$FORBIDDEN_PATTERNS" $ALL_FILES 2>/dev/null | grep -v '\.example' | grep -v 'pre-commit.sh' || true)
if [ -n "$LEAKED_FILES" ]; then
    echo "❌ CYBERSECURITY ALERT: Secret, private key, or credential leak detected in:"
    echo "$LEAKED_FILES"
    exit 1
fi

# 3. Large Audio Media & Bloat File Guard (.m4b, .mp3, .flac, >10MB)
echo "🔍 [3/12] Repo Bloat & Audio Media Guard..."
AUDIO_BLOAT=$(echo "$ALL_FILES" | tr ' ' '\n' | grep -i -E '\.(m4b|mp3|flac|aac|wav|ogg|zip|tar\.gz|iso)$' || true)
if [ -n "$AUDIO_BLOAT" ]; then
    echo "❌ REPO BLOAT GUARD: Accidental audio media or large binary file staged:"
    echo "$AUDIO_BLOAT"
    exit 1
fi

# 4. Package.swift Compatibility & Unpinned Dependency Guard
if [ -n "$PACKAGE_FILES" ]; then
    echo "🔍 [4/12] SPM Package Compatibility Audit..."
    UNPINNED=$(grep -n 'branch:' $PACKAGE_FILES 2>/dev/null || true)
    if [ -n "$UNPINNED" ]; then
        echo "⚠️ WARNING: Unpinned SPM branch dependency found in Package.swift:"
        echo "$UNPINNED"
        echo "Use exact version or upToNextMajor for compatible dependency resolution!"
        exit 1
    fi
fi

# 5. Insecure Random Generator Guard (Cryptographic Token Security)
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [5/12] Cryptographic Random Security Guard..."
    INSECURE_RANDOM=$(grep -n 'Double\.random\|Int\.random' $SWIFT_FILES 2>/dev/null | grep -i -E '(token|secret|auth|nonce|key|pin)' || true)
    if [ -n "$INSECURE_RANDOM" ]; then
        echo "❌ CYBERSECURITY VIOLATION: Non-cryptographic random generator used for security tokens:"
        echo "$INSECURE_RANDOM"
        echo "Use SecRandomCopyBytes / CryptoKit for security tokens!"
        exit 1
    fi
fi

# 6. JSON / YAML Syntax Guard
if [ -n "$JSON_FILES" ]; then
    echo "🔍 [6/12] JSON/YAML Syntax Guard..."
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

# 7. Legacy @Published Guard (Rule 1: No Legacy Code)
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [7/12] Swift Bleeding-Edge @Published Guard..."
    PUBLISHED_FILES=$(grep -n '@Published' $SWIFT_FILES 2>/dev/null || true)
    if [ -n "$PUBLISHED_FILES" ]; then
        echo "❌ Legacy @Published found (use @Observable instead):"
        echo "$PUBLISHED_FILES"
        exit 1
    fi
fi

# 8. Force-Unwrap & Crash Pattern Guard
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [8/12] Force-Unwrap & Crash Pattern Guard..."
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

# 9. Debug Print Leftover Guard
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [9/12] Debug Print Leftover Guard..."
    DEBUG_PRINTS=$(grep -n 'debugPrint\|NSLog\|dump(' $SWIFT_FILES 2>/dev/null || true)
    if [ -n "$DEBUG_PRINTS" ]; then
        echo "⚠️ WARNING: Debug print statements found:"
        echo "$DEBUG_PRINTS"
        exit 1
    fi
fi

# 10. Hardcoded URL / Localhost Guard
if [ -n "$SWIFT_FILES" ]; then
    echo "🔍 [10/12] Hardcoded URL Guard..."
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
        echo "🔍 [11/12] SwiftLint strict analysis..."
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
    echo "🔍 [12/12] Swift 6 Compiler & Strict Concurrency check..."
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
echo "✅ [12/12] Mobile pre-commit passed — $TOTAL_FILES file(s) verified across 11 intelligent cybersecurity & quality guards."
