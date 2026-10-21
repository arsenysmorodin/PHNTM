#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_DIRECTORY="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
BUILD_DIRECTORY="${PROJECT_DIRECTORY}/build/public-release"
DIST_DIRECTORY="${PROJECT_DIRECTORY}/dist"
DERIVED_DATA_DIRECTORY="${BUILD_DIRECTORY}/DerivedData"
STAGING_DIRECTORY="${BUILD_DIRECTORY}/dmg"
APP_NAME="PHNTM"
NOTARY_PROFILE="${NOTARY_PROFILE:-PHNTM-notary}"
DEVELOPER_DIRECTORY="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

export DEVELOPER_DIR="${DEVELOPER_DIRECTORY}"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION}"
else
  SIGNING_IDENTITY="$(
    security find-identity -v -p codesigning \
      | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' \
      | head -n 1
  )"
fi

if [[ -z "${SIGNING_IDENTITY}" ]]; then
  echo "No Developer ID Application certificate was found."
  echo "Install the certificate in Keychain Access or set DEVELOPER_ID_APPLICATION."
  exit 2
fi

if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
  echo "The notarization profile '${NOTARY_PROFILE}' is unavailable."
  echo "Create it with:"
  echo "xcrun notarytool store-credentials '${NOTARY_PROFILE}' --apple-id EMAIL --team-id TEAM_ID --password APP_SPECIFIC_PASSWORD"
  exit 3
fi

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
  --options runtime \
  --timestamp \
  --entitlements "${PROJECT_DIRECTORY}/PHNTM/PHNTM.entitlements" \
  --sign "${SIGNING_IDENTITY}" \
  "${STAGED_APP}"

codesign --verify --deep --strict --verbose=2 "${STAGED_APP}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${STAGED_APP}/Contents/Info.plist")"
APP_ARCHIVE="${BUILD_DIRECTORY}/${APP_NAME}-${VERSION}.zip"
DMG_PATH="${DIST_DIRECTORY}/${APP_NAME}-${VERSION}.dmg"

ditto -c -k --keepParent "${STAGED_APP}" "${APP_ARCHIVE}"
xcrun notarytool submit \
  "${APP_ARCHIVE}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait
xcrun stapler staple "${STAGED_APP}"
xcrun stapler validate "${STAGED_APP}"

ln -s /Applications "${STAGING_DIRECTORY}/Applications"
rm -f "${DMG_PATH}"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIRECTORY}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

codesign \
  --force \
  --timestamp \
  --sign "${SIGNING_IDENTITY}" \
  "${DMG_PATH}"

xcrun notarytool submit \
  "${DMG_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"

spctl --assess --type execute --verbose=4 "${STAGED_APP}"
spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG_PATH}"
shasum -a 256 "${DMG_PATH}" > "${DMG_PATH}.sha256"

echo "Signed and notarized release created:"
echo "${DMG_PATH}"
