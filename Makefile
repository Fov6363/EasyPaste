PROJECT := EasyPaste.xcodeproj
SCHEME := EasyPaste
CONFIGURATION := Debug
RELEASE_CONFIGURATION := Release
DERIVED_DATA := $(CURDIR)/build
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/EasyPaste.app
RELEASE_APP_PATH := $(DERIVED_DATA)/Build/Products/$(RELEASE_CONFIGURATION)/EasyPaste.app
DIST_DIR := $(CURDIR)/dist
PACKAGE_ROOT := $(DIST_DIR)/EasyPaste-trial
PACKAGE_NAME := EasyPaste-trial-macOS.zip
README_PATH := $(CURDIR)/README.md

.PHONY: build release-build run rebuild-run package clean

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

release-build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(RELEASE_CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

run:
	-pkill -x EasyPaste
	@sleep 0.5
	open -n $(APP_PATH)

rebuild-run: build run

package: release-build
	rm -rf $(PACKAGE_ROOT) $(DIST_DIR)/$(PACKAGE_NAME)
	mkdir -p $(PACKAGE_ROOT)
	cp -R $(RELEASE_APP_PATH) $(PACKAGE_ROOT)/
	cp $(README_PATH) $(PACKAGE_ROOT)/
	cd $(DIST_DIR) && ditto -c -k --sequesterRsrc --keepParent EasyPaste-trial $(PACKAGE_NAME)
	@echo "Package created at $(DIST_DIR)/$(PACKAGE_NAME)"

clean:
	rm -rf $(DERIVED_DATA) $(DIST_DIR)
