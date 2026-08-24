# Pilcrow — Lomuscio Labs
# `make run` for day-to-day, `make install` to put it in /Applications.

APP      = Pilcrow
PROJ     = $(APP).xcodeproj
DERIVED  = build
DEBUG    = $(DERIVED)/Build/Products/Debug/$(APP).app
RELEASE  = $(DERIVED)/Build/Products/Release/$(APP).app
# Read from the keychain rather than hardcoded, so this file carries no
# identity and works for anyone with a Developer ID certificate installed.
IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | \
              grep "Developer ID Application" | head -1 | \
              sed -E 's/.*"(.*)".*/\1/')

.PHONY: project dev release run install clean test uninstall notarize zip dmg verify

project:            ## regenerate the Xcode project from project.yml
	xcodegen generate

dev: project        ## debug build
	xcodebuild -project $(PROJ) -scheme $(APP) -configuration Debug \
	  -derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO build | \
	  grep -E "error:|warning:|BUILD" || true

release: project    ## release build, signed with Developer ID
	xcodebuild -project $(PROJ) -scheme $(APP) -configuration Release \
	  -derivedDataPath $(DERIVED) \
	  CODE_SIGN_STYLE=Manual \
	  CODE_SIGN_IDENTITY="$(IDENTITY)" \
	  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
	  OTHER_CODE_SIGN_FLAGS="--timestamp" build | \
	  grep -E "error:|BUILD" || true
	@codesign -dv --verbose=2 "$(RELEASE)" 2>&1 | grep -E "Authority=Developer|TeamIdentifier"

run: dev            ## build and launch
	@killall $(APP) 2>/dev/null || true
	@open "$(DEBUG)"

install: release    ## put it in /Applications
	@killall $(APP) 2>/dev/null || true
	@rm -rf "/Applications/$(APP).app"
	@cp -R "$(RELEASE)" /Applications/
	@echo "Installed to /Applications/$(APP).app"
	@open "/Applications/$(APP).app"

uninstall:
	@killall $(APP) 2>/dev/null || true
	@rm -rf "/Applications/$(APP).app"
	@echo "Removed /Applications/$(APP).app"

test:               ## codec round trip + persistence
	@bash Scripts/test.sh

clean:
	rm -rf $(DERIVED) $(PROJ)

# Notarising is only needed to hand the app to someone else — a locally
# built, Developer-ID-signed app runs on the machine that built it. Store a
# credential once first; see README.md.
zip: release
	@rm -f dist/$(APP).zip && mkdir -p dist
	@ditto -c -k --keepParent "$(RELEASE)" dist/$(APP).zip
	@echo "dist/$(APP).zip"

dmg: release        ## a drag-to-Applications disk image
	@rm -rf dist/dmg dist/$(APP).dmg && mkdir -p dist/dmg
	@cp -R "$(RELEASE)" dist/dmg/
	@ln -s /Applications dist/dmg/Applications
	@hdiutil create -volname "$(APP)" -srcfolder dist/dmg -ov -format UDZO \
	  -quiet dist/$(APP).dmg
	@rm -rf dist/dmg
	@echo "dist/$(APP).dmg  ($$(du -h dist/$(APP).dmg | cut -f1))"

verify:             ## what Gatekeeper thinks of the built app
	@echo "— signature —"
	@codesign -dv --verbose=2 "$(RELEASE)" 2>&1 | grep -E "Authority=|TeamIdentifier|flags"
	@echo "— deep verify —"
	@codesign --verify --deep --strict --verbose=2 "$(RELEASE)" 2>&1 | tail -2
	@echo "— gatekeeper —"
	@spctl -a -vvv "$(RELEASE)" 2>&1 | head -3 || true

# Two submissions on purpose. Stapling the .app covers someone who copies it
# out of the image; stapling the .dmg covers the image itself. Either alone
# leaves one of the two ways people actually receive an app unnotarised.
notarize: zip
	@echo "→ submitting the app"
	xcrun notarytool submit dist/$(APP).zip --keychain-profile pilcrow-notary --wait
	xcrun stapler staple "$(RELEASE)"
	@echo "→ building and signing the image from the stapled app"
	@rm -rf dist/dmg dist/$(APP).dmg && mkdir -p dist/dmg
	@cp -R "$(RELEASE)" dist/dmg/
	@ln -s /Applications dist/dmg/Applications
	@hdiutil create -volname "$(APP)" -srcfolder dist/dmg -ov -format UDZO 	  -quiet dist/$(APP).dmg
	@rm -rf dist/dmg
	@codesign --force --sign "$(IDENTITY)" --timestamp dist/$(APP).dmg
	@echo "→ submitting the image"
	xcrun notarytool submit dist/$(APP).dmg --keychain-profile pilcrow-notary --wait
	xcrun stapler staple dist/$(APP).dmg
	@echo "→ installing the stapled build"
	@killall $(APP) 2>/dev/null || true
	@rm -rf "/Applications/$(APP).app" && cp -R "$(RELEASE)" /Applications/
	@echo
	@spctl -a -vvv "/Applications/$(APP).app" 2>&1 | head -3
	@spctl -a -t open --context context:primary-signature -vvv dist/$(APP).dmg 2>&1 | head -3
