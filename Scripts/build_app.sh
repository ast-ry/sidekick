#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Sidekick"
PRODUCT_NAME="sidekick"
BUILD_DIR="${ROOT_DIR}/.build"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "== Building executable =="
(
  cd "${ROOT_DIR}"
  swift build -c debug
)

echo "== Creating app bundle =="
mkdir -p "${DIST_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/debug/${PRODUCT_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "${ROOT_DIR}/App/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${ROOT_DIR}/App/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

echo "== Ad-hoc signing app bundle =="
codesign --force --deep --sign - "${APP_DIR}"

echo "== Done =="
echo "App bundle: ${APP_DIR}"
echo
echo "Run with:"
echo "open \"${APP_DIR}\""
