#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${ROOT_DIR}/App/Info.plist")"
DMG_PATH="${ROOT_DIR}/dist/Sidekick-${VERSION}.dmg"

if [[ -z "${CODESIGN_IDENTITY:-}" || "${CODESIGN_IDENTITY}" == "-" ]]; then
  echo "CODESIGN_IDENTITY must name a Developer ID Application certificate." >&2
  exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "NOTARY_PROFILE is required." >&2
  exit 1
fi

BUILD_CONFIGURATION=release zsh "${ROOT_DIR}/Scripts/build_dmg.sh"
zsh "${ROOT_DIR}/Scripts/notarize_dmg.sh" "${DMG_PATH}"
