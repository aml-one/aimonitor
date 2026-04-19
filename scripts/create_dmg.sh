#!/usr/bin/env bash
# create_dmg.sh — Build AiMonitor.app and package it into a distributable DMG.
# Usage: bash scripts/create_dmg.sh
set -euo pipefail

# Use Xcode.app's toolchain without requiring sudo xcode-select
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AiMonitor"
SCHEME="AiMonitor"
CONFIGURATION="Release"
ARCHIVE_PATH="$REPO_ROOT/build/AiMonitor.xcarchive"
EXPORT_PATH="$REPO_ROOT/build/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
DMG_PATH="$REPO_ROOT/$APP_NAME.dmg"
DMG_TMP_DIR="$REPO_ROOT/build/dmg_staging"
VOLUME_NAME="$APP_NAME"

# ── 1. Archive ────────────────────────────────────────────────────────────────
echo "▸ Archiving…"
xcodebuild -project "$REPO_ROOT/$APP_NAME.xcodeproj" \
           -scheme "$SCHEME" \
           -configuration "$CONFIGURATION" \
           -archivePath "$ARCHIVE_PATH" \
           archive

# ── 2. Export (ad-hoc, no signing required for local use) ─────────────────────
echo "▸ Exporting…"
EXPORT_OPTIONS_PLIST="$REPO_ROOT/ExportOptions.plist"

if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
  cat > "$EXPORT_OPTIONS_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>mac-application</string>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
PLIST
fi

xcodebuild -exportArchive \
           -archivePath "$ARCHIVE_PATH" \
           -exportPath "$EXPORT_PATH" \
           -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

# ── 3. Stage DMG contents ─────────────────────────────────────────────────────
echo "▸ Staging DMG contents…"
rm -rf "$DMG_TMP_DIR"
mkdir -p "$DMG_TMP_DIR"

cp -R "$APP_PATH" "$DMG_TMP_DIR/"

# Create the /Applications symlink so users can drag-and-drop to install.
ln -s /Applications "$DMG_TMP_DIR/Applications"

# ── 4. Create a read/write DMG ────────────────────────────────────────────────
echo "▸ Creating DMG…"
DMG_RW="$REPO_ROOT/build/${APP_NAME}_rw.dmg"
rm -f "$DMG_RW" "$DMG_PATH"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_TMP_DIR" \
  -ov \
  -format UDRW \
  "$DMG_RW"

# ── 5. Mount the read/write DMG ───────────────────────────────────────────────
echo "▸ Mounting DMG for customisation…"
MOUNT_DIR="$(hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen | \
             awk '/\/Volumes\// { print $NF }')"
echo "  Mounted at: $MOUNT_DIR"
sleep 2   # give Finder time to settle

# ── 6. Customise the window via AppleScript ───────────────────────────────────
echo "▸ Customising DMG appearance…"
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open

    -- Window size and position
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 200, 1000, 600}

    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 160

    -- Item positions
    set position of item "$APP_NAME.app" of container window to {200, 190}
    set position of item "Applications"  of container window to {400, 190}

    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

# Allow changes to flush to disk
sync
sleep 3

# ── 7. Detach and convert to compressed read-only DMG ─────────────────────────
echo "▸ Detaching…"
hdiutil detach "$MOUNT_DIR" -force

echo "▸ Converting to read-only compressed DMG…"
hdiutil convert "$DMG_RW" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

rm -f "$DMG_RW"
rm -rf "$DMG_TMP_DIR"

echo "✔ Done → $DMG_PATH"
