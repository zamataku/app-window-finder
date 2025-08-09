#!/bin/bash

# AppWindowFinder - Complete build and package script
# This script builds the latest code and creates both .app and .dmg

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 AppWindowFinder - Complete Build and Package${NC}"
echo "================================================="

# Configuration
APP_NAME="AppWindowFinder"
BUNDLE_ID="io.github.appwindowfinder"
VERSION="1.0.0"
EXECUTABLE_PATH=".build/release/${APP_NAME}"
OUTPUT_DIR="dist"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_SIZE="200m"

# Step 1: Clean previous builds
echo -e "${YELLOW}📂 Cleaning previous builds...${NC}"
rm -rf .build
rm -rf dist
rm -rf AppWindowFinder.app

# Step 2: Build release version
echo -e "${YELLOW}🏗️  Building release version...${NC}"
swift build -c release

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo "Build complete! ($(date))"

# Step 3: Create app bundle
echo -e "${YELLOW}📦 Creating app bundle...${NC}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Remove existing app bundle
rm -rf "${APP_BUNDLE}"

# Create app bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
echo "Copying executable..."
cp "${EXECUTABLE_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Create Info.plist
echo "Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Copy app icon if it exists
if [ -f "AppIcon.icns" ]; then
    echo "Copying app icon..."
    cp "AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
else
    echo "Creating placeholder icon..."
    touch "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Sign the app bundle if certificate is available
if security find-identity -v -p codesigning | grep -q "Apple Development"; then
    echo "Signing app bundle..."
    codesign --force --deep --sign - "${APP_BUNDLE}"
else
    echo "No code signing certificate found. App will not be signed."
fi

echo "App bundle created: ${APP_BUNDLE}"

# Step 4: Create DMG
echo -e "${YELLOW}💿 Creating DMG...${NC}"

# Clean up any existing DMG
rm -f "${OUTPUT_DIR}/${DMG_NAME}"
rm -f "${OUTPUT_DIR}/temp.dmg"

# Create a temporary DMG
echo "Creating temporary DMG..."
hdiutil create -size ${DMG_SIZE} -fs HFS+ -volname "${VOLUME_NAME}" "${OUTPUT_DIR}/temp.dmg"

# Mount the temporary DMG
echo "Mounting temporary DMG..."
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "${OUTPUT_DIR}/temp.dmg"

# Copy the app
echo "Copying application..."
cp -R "${APP_BUNDLE}" "${MOUNT_DIR}/"

# Remove quarantine attributes from the app
echo "Removing quarantine attributes..."
xattr -cr "${MOUNT_DIR}/${APP_NAME}.app"

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "${MOUNT_DIR}/Applications"

# Set custom icon positions and window properties using AppleScript
echo "Setting DMG window properties..."
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 430}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set position of item "${APP_NAME}.app" of container window to {125, 160}
        set position of item "Applications" of container window to {375, 160}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount the temporary DMG
echo "Unmounting temporary DMG..."
hdiutil detach "${MOUNT_DIR}"

# Convert to compressed DMG
echo "Creating final DMG..."
hdiutil convert "${OUTPUT_DIR}/temp.dmg" -format UDZO -o "${OUTPUT_DIR}/${DMG_NAME}"

# Clean up temporary DMG
rm -f "${OUTPUT_DIR}/temp.dmg"

# Sign the DMG if code signing identity is available
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "Signing DMG..."
    codesign --force --sign "Developer ID Application" "${OUTPUT_DIR}/${DMG_NAME}"
else
    echo "No Developer ID Application certificate found. DMG will not be signed."
fi

echo "DMG created successfully: ${OUTPUT_DIR}/${DMG_NAME}"

# Step 5: Display results
echo ""
echo -e "${GREEN}✅ Build and package complete!${NC}"
echo "================================================="
echo "📱 App bundle: ${APP_BUNDLE}"
echo "💿 DMG file: ${OUTPUT_DIR}/${DMG_NAME}"
echo ""
echo "🔍 File sizes:"
ls -lh "${OUTPUT_DIR}/${DMG_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo ""
echo "DMG Info:"
hdiutil imageinfo "${OUTPUT_DIR}/${DMG_NAME}" | grep -E "(Format:|Size:|Checksum:)"

echo ""
echo -e "${GREEN}🎉 Ready for distribution!${NC}"