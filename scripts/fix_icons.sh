#!/bin/bash
SRC=$1
DEST_IOS=$2
DEST_WEB=$3

echo "Fixing iOS icons to be strict PNG..."
sips -s format png -z 40 40 "$SRC" --out "$DEST_IOS/AppIcon-20@2x.png" > /dev/null
sips -s format png -z 60 60 "$SRC" --out "$DEST_IOS/AppIcon-20@3x.png" > /dev/null
sips -s format png -z 29 29 "$SRC" --out "$DEST_IOS/AppIcon-29.png" > /dev/null
sips -s format png -z 58 58 "$SRC" --out "$DEST_IOS/AppIcon-29@2x.png" > /dev/null
sips -s format png -z 87 87 "$SRC" --out "$DEST_IOS/AppIcon-29@3x.png" > /dev/null
sips -s format png -z 80 80 "$SRC" --out "$DEST_IOS/AppIcon-40@2x.png" > /dev/null
sips -s format png -z 120 120 "$SRC" --out "$DEST_IOS/AppIcon-40@3x.png" > /dev/null
sips -s format png -z 120 120 "$SRC" --out "$DEST_IOS/AppIcon@2x.png" > /dev/null
sips -s format png -z 180 180 "$SRC" --out "$DEST_IOS/AppIcon@3x.png" > /dev/null
sips -s format png -z 20 20 "$SRC" --out "$DEST_IOS/AppIcon-20~ipad.png" > /dev/null
sips -s format png -z 40 40 "$SRC" --out "$DEST_IOS/AppIcon-20@2x~ipad.png" > /dev/null
sips -s format png -z 29 29 "$SRC" --out "$DEST_IOS/AppIcon-29~ipad.png" > /dev/null
sips -s format png -z 58 58 "$SRC" --out "$DEST_IOS/AppIcon-29@2x~ipad.png" > /dev/null
sips -s format png -z 40 40 "$SRC" --out "$DEST_IOS/AppIcon-40~ipad.png" > /dev/null
sips -s format png -z 80 80 "$SRC" --out "$DEST_IOS/AppIcon-40@2x~ipad.png" > /dev/null
sips -s format png -z 76 76 "$SRC" --out "$DEST_IOS/AppIcon~ipad.png" > /dev/null
sips -s format png -z 152 152 "$SRC" --out "$DEST_IOS/AppIcon@2x~ipad.png" > /dev/null
sips -s format png -z 167 167 "$SRC" --out "$DEST_IOS/AppIcon-83.5@2x~ipad.png" > /dev/null
sips -s format png -z 1024 1024 "$SRC" --out "$DEST_IOS/AppIcon~ios-marketing.png" > /dev/null

echo "Fixing Web icons to be strict PNG..."
sips -s format png "$SRC" --out "$DEST_WEB/public/images/logo.png" > /dev/null
sips -s format png -z 192 192 "$SRC" --out "$DEST_WEB/public/images/icon192.png" > /dev/null
sips -s format png -z 64 64 "$SRC" --out "$DEST_WEB/public/images/icon64.png" > /dev/null
sips -s format png -z 180 180 "$SRC" --out "$DEST_WEB/src/app/apple-icon.png" > /dev/null

echo "Removing the uppercase Logo.png to avoid case issues in manifest..."
rm -f "$DEST_WEB/public/images/Logo.png"

echo "Done!"
