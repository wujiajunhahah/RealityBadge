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

Advanced (Vision object detection)
- By default, subject masks use Apple saliency/Portrait Matte for broad compatibility.
- To prefer Apple’s VNRecognizeObjectsRequest (iOS 17+), enable the Swift flag and rebuild:
  - Xcode → Target → Build Settings → Other Swift Flags → add `-D USE_VN_OBJECTS` for Debug.
  - If your SDK doesn’t expose the symbol, keep the flag off; the app auto‑falls back to saliency.

Xcode way
- Open `RealityBadge.xcodeproj` → select target `RealityBadge` → Signing & Capabilities:
  - Team: your Apple ID
  - Enable “Automatically manage signing”
  - Bundle Identifier: set to `com.yourcompany.realitybadges`
- Choose your iPhone in the run destination and press ⌘R.
