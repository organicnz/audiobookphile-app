#!/bin/sh
set -e

echo "=== ci_post_xcodebuild.sh ==="
echo "CI_ARCHIVE_PATH: ${CI_ARCHIVE_PATH}"
echo "CI_PRODUCT: ${CI_PRODUCT}"
echo "CI_XCODEBUILD_ACTION: ${CI_XCODEBUILD_ACTION}"
echo "CI_XCODEBUILD_EXIT_CODE: ${CI_XCODEBUILD_EXIT_CODE}"

# Dump the archive structure so we can see what's inside
if [ -n "$CI_ARCHIVE_PATH" ] && [ -d "$CI_ARCHIVE_PATH" ]; then
    echo "=== Archive Products Directory ==="
    find "$CI_ARCHIVE_PATH/Products" -type f 2>/dev/null || echo "(no Products dir)"
    echo "=== Archive Info.plist ==="
    cat "$CI_ARCHIVE_PATH/Info.plist" 2>/dev/null || echo "(no Info.plist)"
    echo "=== Frameworks inside .app ==="
    find "$CI_ARCHIVE_PATH" -name "*.framework" -o -name "*.dylib" 2>/dev/null || echo "(none)"
fi

# Dump export logs if they exist
echo "=== Checking for export logs ==="
for logdir in /Volumes/workspace/tmp/*-export-archive-logs; do
    if [ -d "$logdir" ]; then
        echo "=== Export logs in $logdir ==="
        find "$logdir" -name "*.log" -exec sh -c 'echo "--- {} ---"; cat "{}"' \;
    fi
done

# Also check for IDEDistribution logs
find /Volumes/workspace/tmp -name "IDEDistribution*" -type f 2>/dev/null | while read f; do
    echo "=== $f ==="
    cat "$f"
done

echo "=== ci_post_xcodebuild.sh complete ==="
