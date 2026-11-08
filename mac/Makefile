APP_NAME := Garmin Clicker
EXECUTABLE := GarminClicker
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app

# Created once by scripts/make-signing-cert.sh. A stable identity keeps the
# Accessibility grant across rebuilds; ad-hoc signing ("-") does not.
LOCAL_IDENTITY := Garmin Clicker Local
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -q '"$(LOCAL_IDENTITY)"' && echo "$(LOCAL_IDENTITY)" || echo "-")

.PHONY: test app run clean

test:
	swift test

app:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$$(swift build -c release --show-bin-path)/$(EXECUTABLE)" "$(APP)/Contents/MacOS/$(EXECUTABLE)"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	cp -R Resources/*.lproj "$(APP)/Contents/Resources/"
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		echo "warning: signing identity '$(LOCAL_IDENTITY)' not found, using ad-hoc signing." >&2; \
		echo "warning: the Accessibility permission will be reset after every rebuild;" >&2; \
		echo "warning: run scripts/make-signing-cert.sh once to fix this." >&2; \
	fi
	codesign --force --sign "$(SIGN_IDENTITY)" --options runtime "$(APP)"

run: app
	open "$(APP)"

clean:
	rm -rf "$(BUILD_DIR)" .build
