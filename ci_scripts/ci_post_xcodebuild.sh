#!/bin/sh
# Don't use set -e — we want all diagnostics to run even if some fail
set +e

echo "========================================"
echo "=== ci_post_xcodebuild.sh diagnostics ==="
echo "========================================"
echo "CI_ARCHIVE_PATH: ${CI_ARCHIVE_PATH}"
echo "CI_PRODUCT: ${CI_PRODUCT}"
echo "CI_XCODEBUILD_ACTION: ${CI_XCODEBUILD_ACTION}"
echo "CI_XCODEBUILD_EXIT_CODE: ${CI_XCODEBUILD_EXIT_CODE}"
echo "CI_DERIVED_DATA_PATH: ${CI_DERIVED_DATA_PATH}"
echo "CI_RESULT_BUNDLE_PATH: ${CI_RESULT_BUNDLE_PATH}"

# ─── 1. Archive structure ───
if [ -n "$CI_ARCHIVE_PATH" ] && [ -d "$CI_ARCHIVE_PATH" ]; then
    echo ""
    echo "=== 1. FULL ARCHIVE TREE (depth 5) ==="
    find "$CI_ARCHIVE_PATH" -maxdepth 5 -print 2>/dev/null

    echo ""
    echo "=== 2. ARCHIVE Info.plist ==="
    cat "$CI_ARCHIVE_PATH/Info.plist" 2>/dev/null || echo "(no Info.plist)"

    # Find the .app inside the archive
    APP_PATH=$(find "$CI_ARCHIVE_PATH/Products" -name "*.app" -type d -maxdepth 3 2>/dev/null | head -1)
    echo ""
    echo "=== 3. APP BUNDLE PATH: ${APP_PATH:-NOT FOUND} ==="

    if [ -n "$APP_PATH" ]; then
        echo ""
        echo "=== 4. APP Info.plist ==="
        cat "$APP_PATH/Info.plist" 2>/dev/null | head -60 || echo "(no Info.plist in app)"

        echo ""
        echo "=== 5. APP BUNDLE CONTENTS ==="
        ls -laR "$APP_PATH" 2>/dev/null | head -100

        echo ""
        echo "=== 6. EMBEDDED FRAMEWORKS ==="
        ls -la "$APP_PATH/Frameworks/" 2>/dev/null || echo "(no Frameworks dir)"

        echo ""
        echo "=== 7. CODE SIGNATURE OF APP ==="
        codesign -dvvv "$APP_PATH" 2>&1 || echo "(codesign -d failed)"

        echo ""
        echo "=== 8. CODE SIGNATURE VERIFICATION ==="
        codesign --verify --deep --strict --verbose=4 "$APP_PATH" 2>&1 || echo "(codesign --verify failed)"

        echo ""
        echo "=== 9. ENTITLEMENTS ==="
        codesign -d --entitlements - "$APP_PATH" 2>&1 || echo "(no entitlements)"

        # Check each framework
        if [ -d "$APP_PATH/Frameworks" ]; then
            for fw in "$APP_PATH/Frameworks"/*.framework; do
                if [ -d "$fw" ]; then
                    echo ""
                    echo "=== 10. FRAMEWORK: $(basename $fw) ==="
                    echo "--- Info.plist ---"
                    cat "$fw/Info.plist" 2>/dev/null | head -30 || echo "(no Info.plist)"
                    echo "--- Code Signature ---"
                    codesign -dvvv "$fw" 2>&1 || echo "(unsigned)"
                    echo "--- Architectures ---"
                    lipo -info "$fw/$(basename $fw .framework)" 2>/dev/null || echo "(lipo failed)"
                fi
            done

            for dylib in "$APP_PATH/Frameworks"/*.dylib; do
                if [ -f "$dylib" ]; then
                    echo ""
                    echo "=== 10. DYLIB: $(basename $dylib) ==="
                    echo "--- Code Signature ---"
                    codesign -dvvv "$dylib" 2>&1 || echo "(unsigned)"
                    echo "--- Architectures ---"
                    lipo -info "$dylib" 2>/dev/null || echo "(lipo failed)"
                fi
            done
        fi
    fi
else
    echo ""
    echo "=== WARNING: No archive found at CI_ARCHIVE_PATH ==="
fi

# ─── 2. Export error logs ───
echo ""
echo "========================================"
echo "=== EXPORT ERROR LOGS ==="
echo "========================================"

# Check all export log directories
for logdir in /Volumes/workspace/tmp/*-export-archive-logs; do
    if [ -d "$logdir" ]; then
        echo ""
        echo "=== Export logs in: $logdir ==="
        find "$logdir" -type f 2>/dev/null | while read f; do
            echo ""
            echo "--- $f ---"
            cat "$f" 2>/dev/null
        done
    fi
done

# IDEDistribution logs (often contain the real error)
echo ""
echo "=== IDEDistribution logs ==="
find /Volumes/workspace/tmp -name "IDEDistribution*" -type f 2>/dev/null | while read f; do
    echo ""
    echo "--- $f ---"
    cat "$f" 2>/dev/null
done

# Any .log files in tmp
echo ""
echo "=== Other log files in /Volumes/workspace/tmp ==="
find /Volumes/workspace/tmp -name "*.log" -type f 2>/dev/null | while read f; do
    echo ""
    echo "--- $f ---"
    tail -100 "$f" 2>/dev/null
done

# ─── 3. Xcode Cloud export plists ───
echo ""
echo "========================================"
echo "=== EXPORT OPTIONS PLISTS ==="
echo "========================================"
for plist in /Volumes/workspace/ci/*-exportoptions.plist; do
    if [ -f "$plist" ]; then
        echo ""
        echo "--- $plist ---"
        cat "$plist" 2>/dev/null
    fi
done

# ─── 4. Provisioning profiles ───
echo ""
echo "========================================"
echo "=== PROVISIONING PROFILES ==="
echo "========================================"
find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.mobileprovision" 2>/dev/null | while read p; do
    echo ""
    echo "--- $(basename "$p") ---"
    security cms -D -i "$p" 2>/dev/null | grep -A2 "Name\|TeamIdentifier\|application-identifier\|Entitlements" | head -20
done

# ─── 5. Available signing identities ───
echo ""
echo "=== SIGNING IDENTITIES ==="
security find-identity -v -p codesigning 2>/dev/null | head -20 || echo "(none found)"

echo ""
echo "========================================"
echo "=== ci_post_xcodebuild.sh complete ==="
echo "========================================"
