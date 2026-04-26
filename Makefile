PKG_DIR := NepaliCalendar
APP_NAME := NepaliCalendar
BUILD_DIR := build
RELEASE_BIN := $(PKG_DIR)/.build/apple/Products/Release/$(APP_NAME).app

.PHONY: build run debug clean release open

# Debug build (fast, for development)
build:
	cd $(PKG_DIR) && swift build

# Release build
release:
	cd $(PKG_DIR) && swift build -c release

# Debug build + run
run: build
	cd $(PKG_DIR) && swift run

# Run the release .app bundle (builds if needed)
open: release
	open $(RELEASE_BIN)

# Full release build: universal binary, .app bundle, codesign, zip
dist:
	APP_VERSION=$(or $(VERSION),0.1.0) ./scripts/build-app.sh

# Clean all build artifacts
clean:
	cd $(PKG_DIR) && swift package clean
	rm -rf $(BUILD_DIR)
