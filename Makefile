PROJECT := EasyPaste.xcodeproj
SCHEME := EasyPaste
CONFIGURATION := Debug
DERIVED_DATA := $(CURDIR)/build
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/EasyPaste.app

.PHONY: build run rebuild-run clean

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

run:
	-pkill -x EasyPaste
	@sleep 0.5
	open -n $(APP_PATH)

rebuild-run: build run

clean:
	rm -rf $(DERIVED_DATA)
