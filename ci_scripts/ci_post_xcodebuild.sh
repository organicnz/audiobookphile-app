#!/bin/sh
set -e

echo "=== Running ci_post_xcodebuild.sh ==="

# Check if the Xcode Cloud archive path exists
if [ -z "$CI_ARCHIVE_PATH" ] || [ ! -d "$CI_ARCHIVE_PATH" ]; then
    echo "No archive found. Exiting."
    exit 0
fi

echo "Cleaning up dynamic libraries from archive products to prevent export error 70..."

# Remove 'usr' directory which often contains the .dylib (e.g., usr/local/lib)
if [ -d "$CI_ARCHIVE_PATH/Products/usr" ]; then
    echo "Found usr in archive Products. Deleting..."
    rm -rf "$CI_ARCHIVE_PATH/Products/usr"
fi

# Remove any top-level dylibs in the Products directory
find "$CI_ARCHIVE_PATH/Products" -maxdepth 1 -name "*.dylib" -type f -exec rm -f {} +
echo "Archive cleanup complete. The Export phase should now succeed."
