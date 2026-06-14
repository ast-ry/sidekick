#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Sidekick"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
DMG_ROOT="${DIST_DIR}/dmg-root"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"

echo "== Building app bundle =="
zsh "${ROOT_DIR}/Scripts/build_app.sh"

echo "== Creating DMG staging folder =="
rm -rf "${DMG_ROOT}" "${DMG_PATH}"
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

echo "== Done =="
echo "Disk image: ${DMG_PATH}"
echo
echo "Install with:"
echo "open \"${DMG_PATH}\""
