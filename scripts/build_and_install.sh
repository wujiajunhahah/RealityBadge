#!/usr/bin/env bash
set -euo pipefail

# RealityBadge – Build, sign and install to a connected iOS device.
# Usage:
#   TEAM_ID=XXXXXXXX BUNDLE_ID=com.your.bundle ./scripts/build_and_install.sh [--udid <device-udid>] [--scheme RealityBadge] [--config Debug]
# Notes:
# - Requires: Xcode 15+, a connected iPhone with Developer Mode ON, your Apple ID signed in Xcode.
# - xcodebuild will use Automatic Signing (-allowProvisioningUpdates). No project edits needed.

SCHEME="RealityBadge"
CONFIG="Debug"
UDID=""
# Internal: physical device UDID for xcodebuild destination (differs from CoreDevice Identifier)
XCODE_DEST_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid) UDID="$2"; shift 2;;
    --scheme) SCHEME="$2"; shift 2;;
    --config) CONFIG="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

if [[ -z "${TEAM_ID:-}" ]]; then
  echo "[!] Please export TEAM_ID (your 10‑char Apple Team ID)."
  echo "    Example: export TEAM_ID=ABCDE12345"
  exit 1
fi
if [[ -z "${BUNDLE_ID:-}" ]]; then
  echo "[!] Please export BUNDLE_ID (unique bundle id)."
  echo "    Example: export BUNDLE_ID=com.yourcompany.realitybadges"
  exit 1
fi

echo "==> Detecting device UDID..."
if [[ -z "$UDID" ]]; then
  if command -v xcrun >/dev/null 2>&1; then
    # Prefer devicectl (Xcode 15+)
    set +e
    UDID=$(xcrun devicectl list devices 2>/dev/null | sed -n 's/^\s*\* Device: \([^()]*\) (.*) (\([A-F0-9-]\+\)).*$/\2/p' | head -n1)
    set -e
  fi
fi

if [[ -z "$UDID" ]]; then
  echo "[i] Could not auto-detect UDID. You can list devices with:"
  echo "    xcrun devicectl list devices"
  echo "    xcrun xctrace list devices"
  echo "    Then pass --udid <UDID>"
fi

DERIVED="$(pwd)/build/Derived"
APP_PATH="$DERIVED/Build/Products/$CONFIG-iphoneos/$SCHEME.app"

# If a device identifier is provided, resolve the physical UDID for xcodebuild
if [[ -n "$UDID" ]]; then
  set +e
  PHYS_JSON="$(mktemp)"
  if xcrun devicectl device info details --device "$UDID" --json-output "$PHYS_JSON" >/dev/null 2>&1; then
    XCODE_DEST_ID=$(jq -r '.device.hardwareProperties.udid // empty' "$PHYS_JSON" 2>/dev/null || true)
  fi
  rm -f "$PHYS_JSON" || true
  set -e
fi

echo "==> Building ($SCHEME, $CONFIG) for device (automatic signing)"
if command -v xcpretty >/dev/null 2>&1; then
  XCPIPE="| xcpretty"
else
  XCPIPE=""
fi

set -o pipefail
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  $( [[ -n "$XCODE_DEST_ID" ]] && echo -destination "platform=iOS,id=$XCODE_DEST_ID" || echo -destination 'generic/platform=iOS' ) \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic \
  build ${XCPIPE}
RC=$?
set +o pipefail
if [[ $RC -ne 0 ]]; then
  echo "[!] xcodebuild failed ($RC). If this says 'No Account for Team', open Xcode once and add your Apple ID in Settings > Accounts, then re-run."
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "[!] Build did not produce app at: $APP_PATH"
  exit 2
fi

if [[ -z "$UDID" ]]; then
  echo "[!] No device UDID set. App built at: $APP_PATH"
  exit 0
fi

echo "==> Installing to device $UDID"
set +e
xcrun devicectl device install app --device "$UDID" --app "$APP_PATH"
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  if command -v ios-deploy >/dev/null 2>&1; then
    echo "==> Falling back to ios-deploy"
    if [[ -n "$UDID" ]]; then
      ios-deploy --id "$UDID" --bundle "$APP_PATH" --justlaunch
    else
      ios-deploy --bundle "$APP_PATH" --justlaunch
    fi
  else
    echo "[!] Install failed and ios-deploy not found. Install with: npm i -g ios-deploy"
    exit 3
  fi
fi

echo "✅ Installed. If it doesn't auto-launch, tap the icon on the device."
