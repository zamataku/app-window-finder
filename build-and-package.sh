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
APP_NAME="${APP_NAME:-AppWindowFinder}"
BUNDLE_ID="${BUNDLE_ID:-io.github.appwindowfinder}"
VERSION="${VERSION:-1.0.0}"
BUILD_VERSION="${BUILD_VERSION:-1}"
MIN_OS="${MIN_OS:-13.0}"
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

## Create Info.plist from template
echo "Creating Info.plist from template..."
TEMPLATE_PATH="Sources/AppWindowFinder/Resources/Info.plist.template"
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo -e "${RED}❌ Missing Info.plist template at $TEMPLATE_PATH${NC}"
    exit 1
fi

sed \
  -e "s|\${APP_NAME}|${APP_NAME}|g" \
  -e "s|\${BUNDLE_ID}|${BUNDLE_ID}|g" \
  -e "s|\${VERSION}|${VERSION}|g" \
  -e "s|\${BUILD_VERSION}|${BUILD_VERSION}|g" \
  -e "s|\${MIN_OS}|${MIN_OS}|g" \
  "$TEMPLATE_PATH" > "${APP_BUNDLE}/Contents/Info.plist"

# Copy app icon (prefer Resources, fallback to root)
if [ -f "Sources/AppWindowFinder/Resources/AppIcon.icns" ]; then
    echo "Copying app icon from Resources..."
    cp "Sources/AppWindowFinder/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
elif [ -f "AppIcon.icns" ]; then
    echo "Copying app icon from root..."
    cp "AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
else
    echo "Creating placeholder icon..."
    touch "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Codesign
if [ -n "${CODESIGN_IDENTITY}" ]; then
    echo "Signing app bundle with identity: ${CODESIGN_IDENTITY}"
    codesign --force --deep --timestamp --options runtime --sign "${CODESIGN_IDENTITY}" "${APP_BUNDLE}"
    codesign --verify --deep --strict "${APP_BUNDLE}"
else
    echo "No CODESIGN_IDENTITY provided. Using ad-hoc signing."
    codesign --force --deep --sign - "${APP_BUNDLE}" || true
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
if [ ! -L "${MOUNT_DIR}/Applications" ]; then
    ln -s /Applications "${MOUNT_DIR}/Applications"
fi

# Set custom icon positions and window properties using AppleScript
echo "Setting DMG window properties..."
if ! osascript <<EOF 2>/dev/null
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
then
    echo "⚠️  AppleScript execution failed (automation permissions may be required)"
    echo "   DMG will be created without custom window properties"
fi

# Unmount the temporary DMG
echo "Unmounting temporary DMG..."
hdiutil detach "${MOUNT_DIR}"

# Convert to compressed DMG
echo "Creating final DMG..."
hdiutil convert "${OUTPUT_DIR}/temp.dmg" -format UDZO -o "${OUTPUT_DIR}/${DMG_NAME}"

# Clean up temporary DMG
rm -f "${OUTPUT_DIR}/temp.dmg"

# Optionally sign DMG (requires Developer ID Application)
if [ -n "${DMG_SIGN_IDENTITY}" ]; then
    echo "Signing DMG with identity: ${DMG_SIGN_IDENTITY}"
    codesign --force --sign "${DMG_SIGN_IDENTITY}" "${OUTPUT_DIR}/${DMG_NAME}" || true
else
    echo "No DMG_SIGN_IDENTITY provided. DMG will not be signed."
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
