#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Sidekick"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
DMG_ROOT="${DIST_DIR}/dmg-root"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${ROOT_DIR}/App/Info.plist")"

if [[ "${CODESIGN_IDENTITY}" == "-" ]]; then
  DMG_FILENAME="${APP_NAME}-${VERSION}-unnotarized.dmg"
else
  DMG_FILENAME="${APP_NAME}-${VERSION}.dmg"
fi

DMG_PATH="${DIST_DIR}/${DMG_FILENAME}"
CHECKSUM_PATH="${DMG_PATH}.sha256"
LEGACY_DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"

echo "== Building app bundle =="
zsh "${ROOT_DIR}/Scripts/build_app.sh"

echo "== Creating DMG staging folder =="
rm -rf "${DMG_ROOT}" "${DMG_PATH}" "${CHECKSUM_PATH}" "${LEGACY_DMG_PATH}"
mkdir -p "${DMG_ROOT}"
cp -R "${APP_DIR}" "${DMG_ROOT}/${APP_NAME}.app"
ln -s /Applications "${DMG_ROOT}/Applications"

echo "== Creating disk image =="
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_ROOT}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

if [[ "${CODESIGN_IDENTITY}" != "-" ]]; then
  echo "== Signing disk image with Developer ID =="
  codesign --force --timestamp --sign "${CODESIGN_IDENTITY}" "${DMG_PATH}"
fi

hdiutil verify "${DMG_PATH}"
(
  cd "${DIST_DIR}"
  shasum -a 256 "${DMG_FILENAME}"
) > "${CHECKSUM_PATH}"

echo "== Done =="
echo "Disk image: ${DMG_PATH}"
echo "SHA-256: ${CHECKSUM_PATH}"
cat "${CHECKSUM_PATH}"
echo
echo "Install with:"
echo "open \"${DMG_PATH}\""
