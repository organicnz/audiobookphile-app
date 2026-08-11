#!/bin/bash

echo "🔒 Running Mobile Security & Package Audit..."

# 1. Secret Scan Audit
FORBIDDEN_PATTERNS="eyJhbGci|sbp_[a-zA-Z0-9]{20,}|SUPABASE_SERVICE_ROLE_KEY=[a-zA-Z0-9]|BEGIN PRIVATE KEY|sk_live_[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}"
LEAKS=$(grep -r -E -n "$FORBIDDEN_PATTERNS" Sources/ 2>/dev/null | grep -v '\.example' || true)
if [ -n "$LEAKS" ]; then
    echo "❌ SECURITY AUDIT FAILED: Hardcoded secret/key leak detected:"
    echo "$LEAKS"
    exit 1
fi

# 2. Hardcoded Localhost URL Audit
HARDCODED=$(grep -r -n 'http://localhost\|127\.0\.0\.1\|http://0\.0\.0\.0' Sources/ 2>/dev/null | grep -v 'Mock' | grep -v 'Preview' || true)
if [ -n "$HARDCODED" ]; then
    echo "⚠️ SECURITY WARNING: Hardcoded localhost URLs in production app code:"
    echo "$HARDCODED"
    exit 1
fi

# 3. Cryptographic Token Security (Double.random)
DOUBLE_RANDOM=$(grep -r -n -E 'Double\.random|Math\.random\(' Sources/ 2>/dev/null | grep -v 'GlassParticles' | grep -v 'LibraryService' || true)
if [ -n "$DOUBLE_RANDOM" ]; then
    echo "❌ SECURITY AUDIT FAILED: Insecure random number generator found:"
    echo "$DOUBLE_RANDOM"
    exit 1
fi

# 4. SPM Package Bounding Audit
UNPINNED=$(grep -n 'branch:' Package.swift 2>/dev/null || true)
if [ -n "$UNPINNED" ]; then
    echo "⚠️ PACKAGE AUDIT WARNING: Unpinned SPM branch dependency found in Package.swift:"
    echo "$UNPINNED"
    exit 1
fi

echo "✅ Mobile Security & Package Audit Passed Cleanly!"
