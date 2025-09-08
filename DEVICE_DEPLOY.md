RealityBadge – Device Deploy Quick Guide
======================================

Prereqs
- Xcode 15+
- iPhone/iPad connected via USB, Developer Mode ON
- Xcode → Settings → Accounts: Sign in with your Apple ID

One‑liner (recommended)
```bash
# Replace with your Apple Team ID and a unique bundle id
export TEAM_ID=ABCDE12345
export BUNDLE_ID=com.yourcompany.realitybadges
./scripts/build_and_install.sh --udid <YOUR-DEVICE-UDID>
```

Tips
- Find UDID:
  - `xcrun devicectl list devices` or `xcrun xctrace list devices`
- If install fails, try: `npm i -g ios-deploy` and re‑run the script (it will fallback).
- First run may ask you to trust the developer on device: Settings → General → VPN & Device Management → Developer App → Trust.

Xcode way
- Open `RealityBadge.xcodeproj` → select target `RealityBadge` → Signing & Capabilities:
  - Team: your Apple ID
  - Enable “Automatically manage signing”
  - Bundle Identifier: set to `com.yourcompany.realitybadges`
- Choose your iPhone in the run destination and press ⌘R.

