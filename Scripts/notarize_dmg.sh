#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="${1:-${ROOT_DIR}/dist/Sidekick.dmg}"

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "NOTARY_PROFILE is required. Create one with 'xcrun notarytool store-credentials'." >&2
  exit 1
fi

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "Disk image not found: ${DMG_PATH}" >&2
  exit 1
fi

xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"
spctl --assess --type open --context context:primary-signature --verbose=2 "${DMG_PATH}"
