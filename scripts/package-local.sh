#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_DIRECTORY="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
BUILD_DIRECTORY="${PROJECT_DIRECTORY}/build/local-release"
DIST_DIRECTORY="${PROJECT_DIRECTORY}/dist"
DERIVED_DATA_DIRECTORY="${BUILD_DIRECTORY}/DerivedData"
STAGING_DIRECTORY="${BUILD_DIRECTORY}/dmg"
APP_NAME="PHNTM"
DEVELOPER_DIRECTORY="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

export DEVELOPER_DIR="${DEVELOPER_DIRECTORY}"

rm -rf "${BUILD_DIRECTORY}"
mkdir -p "${STAGING_DIRECTORY}" "${DIST_DIRECTORY}"

xcodebuild \
  -project "${PROJECT_DIRECTORY}/PHNTM.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_DIRECTORY}" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

SOURCE_APP="${DERIVED_DATA_DIRECTORY}/Build/Products/Release/${APP_NAME}.app"
STAGED_APP="${STAGING_DIRECTORY}/${APP_NAME}.app"

ditto "${SOURCE_APP}" "${STAGED_APP}"

codesign \
  --force \
  --sign - \
  --requirements '=designated => identifier "arsenysmorodin.PHNTM"' \
  "${STAGED_APP}"

codesign --verify --deep --strict --verbose=2 "${STAGED_APP}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${STAGED_APP}/Contents/Info.plist")"
DMG_PATH="${DIST_DIRECTORY}/${APP_NAME}-${VERSION}-local.dmg"

ln -s /Applications "${STAGING_DIRECTORY}/Applications"
rm -f "${DMG_PATH}"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIRECTORY}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

shasum -a 256 "${DMG_PATH}" > "${DMG_PATH}.sha256"

echo "Local test package created:"
echo "${DMG_PATH}"
echo "This ad-hoc build is for testing only and will not pass Gatekeeper on another Mac."
