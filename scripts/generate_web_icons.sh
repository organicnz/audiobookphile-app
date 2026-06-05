#!/bin/bash
SRC=$1
DEST_WEB=$2

if [ -z "$SRC" ] || [ -z "$DEST_WEB" ]; then
    echo "Usage: ./generate_web_icons.sh <source_image> <dest_web_dir>"
    exit 1
fi

echo "Generating web icons..."
# Logo
cp "$SRC" "$DEST_WEB/public/images/Logo.png"

# icon192 and icon64
sips -z 192 192 "$SRC" --out "$DEST_WEB/public/images/icon192.png"
sips -z 64 64 "$SRC" --out "$DEST_WEB/public/images/icon64.png"

# Apple Touch Icon (Next.js automatically looks for this in app/ or public/)
sips -z 180 180 "$SRC" --out "$DEST_WEB/src/app/apple-icon.png"

# Favicon (ico format)
sips -z 32 32 -s format ico "$SRC" --out "$DEST_WEB/src/app/favicon.ico"

echo "Done generating web icons."
