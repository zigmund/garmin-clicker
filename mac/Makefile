APP_NAME := Garmin Clicker
EXECUTABLE := GarminClicker
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app

# Created once by scripts/make-signing-cert.sh. A stable identity keeps the
# Accessibility grant across rebuilds; ad-hoc signing ("-") does not.
LOCAL_IDENTITY := Garmin Clicker Local
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -q '"$(LOCAL_IDENTITY)"' && echo "$(LOCAL_IDENTITY)" || echo "-")

# Version source of truth: git tags vX.Y.Z. CI passes all of these explicitly.
VERSION ?= $(shell git describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null | sed 's/^v//' | grep . || echo 0.0.0)
BUILD ?= $(shell git rev-list --count HEAD 2>/dev/null | grep . || echo 1)
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null)$(shell git diff --quiet HEAD -- . 2>/dev/null || echo +)
# Optional keychain holding SIGN_IDENTITY (used on CI).
KEYCHAIN ?=
CODESIGN_KEYCHAIN := $(if $(KEYCHAIN),--keychain "$(KEYCHAIN)")
ZIP := $(BUILD_DIR)/GarminClicker-macOS-$(VERSION).zip

.PHONY: test app zip run clean

test:
	swift test

app:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$$(swift build -c release --show-bin-path)/$(EXECUTABLE)" "$(APP)/Contents/MacOS/$(EXECUTABLE)"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" "$(APP)/Contents/Info.plist"
	plutil -replace CFBundleVersion -string "$(BUILD)" "$(APP)/Contents/Info.plist"
	plutil -replace GCCommit -string "$(COMMIT)" "$(APP)/Contents/Info.plist"
	cp -R Resources/*.lproj "$(APP)/Contents/Resources/"
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		echo "warning: signing identity '$(LOCAL_IDENTITY)' not found, using ad-hoc signing." >&2; \
		echo "warning: the Accessibility permission will be reset after every rebuild;" >&2; \
		echo "warning: run scripts/make-signing-cert.sh once to fix this." >&2; \
	fi
	codesign --force --sign "$(SIGN_IDENTITY)" $(CODESIGN_KEYCHAIN) --options runtime "$(APP)"

zip: app
	rm -f "$(ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(ZIP)"
	@echo "$(ZIP)"

run: app
	open "$(APP)"

clean:
	rm -rf "$(BUILD_DIR)" .build
