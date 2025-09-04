PROJECT=RealityBadge.xcodeproj
SCHEME=RealityBadge
DERIVED=build
APP_NAME=RealityBadge
CONFIG=Debug
# Override these on CLI when needed:
#   make run UDID=<device-udid> TEAM=<teamid>
TEAM?=
UDID?=
BUNDLEID?=com.example.RealityBadge

.PHONY: open list devices build-ios build-sim clean build-device app-path install launch run logs apps uninstall kill doctor

open:
	@open $(PROJECT)

list:
	@xcodebuild -list -project $(PROJECT)

devices:
	@xcrun xctrace list devices

build-ios:
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -destination "generic/platform=iOS" -allowProvisioningUpdates build

build-sim:
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -destination 'platform=iOS Simulator,name=iPhone 15' build

build-device:
	@if [ -z "$(UDID)" ]; then echo "UDID is required. Use: make build-device UDID=<device-udid> [TEAM=<teamid>]"; exit 1; fi
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) \
		-destination "id=$(UDID)" \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=$(TEAM) \
		CODE_SIGN_IDENTITY="Apple Development" \
		PRODUCT_BUNDLE_IDENTIFIER=$(BUNDLEID) \
		-allowProvisioningUpdates \
		build

APP_DIR=$(DERIVED)/Build/Products/$(CONFIG)-iphoneos
APP_PATH=$(APP_DIR)/$(APP_NAME).app

app-path:
	@echo $(APP_PATH)

install:
	@if [ -z "$(UDID)" ]; then echo "UDID is required. Use: make install UDID=<device-udid>"; exit 1; fi
	@xcrun devicectl device install app --device $(UDID) $(APP_PATH)

launch:
	@if [ -z "$(UDID)" ]; then echo "UDID is required. Use: make launch UDID=<device-udid>"; exit 1; fi
	@xcrun devicectl device process launch --device $(UDID) $(BUNDLEID) --activate || true


run: build-device install launch

logs:
	@if [ -z "$(UDID)" ]; then echo "UDID is required. Use: make logs UDID=<device-udid>"; exit 1; fi
	@xcrun devicectl device console $(UDID)

doctor:
	@echo "[Doctor] Xcode:"
	@xcodebuild -version || echo "xcodebuild not found"
	@echo "\n[Doctor] devicectl location:"
	@xcrun -f devicectl || echo "devicectl not found (Xcode 15+ required)"
	@echo "\n[Doctor] Devices (xctrace):"
	@xcrun xctrace list devices | sed -n '1,80p' || true
	@echo "\n[Doctor] Project schemes:"
	@xcodebuild -list -project $(PROJECT) || true
	@echo "\n[Doctor] Using bundle id: $(BUNDLEID)"

apps:
	@if [ -z "$(UDID)" ]; then echo "UDID is required. Use: make apps UDID=<device-udid>"; exit 1; fi
	@xcrun devicectl device app list $(UDID) | sed -n '1,200p'

uninstall:
	@if [ -z "$(UDID)" ]; then echo "UDID is required. Use: make uninstall UDID=<device-udid> [BUNDLEID=com.xxx]"; exit 1; fi
	@xcrun devicectl device uninstall app --device $(UDID) $(BUNDLEID) || true

kill:
	@if [ -z "$(UDID)" ]; then echo "UDID is required. Use: make kill UDID=<device-udid> [BUNDLEID=com.xxx]"; exit 1; fi
	@echo "Use 'devicectl device process terminate --device $(UDID) --pid <pid>' to kill a process"; exit 0
