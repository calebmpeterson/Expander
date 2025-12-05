SWIFT := swiftc
SOURCES := src/*.swift
FRAMEWORKS := -framework AppKit -framework ApplicationServices
APP_NAME := Expander
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS
EXECUTABLE := $(APP_MACOS)/$(APP_NAME)
INFO_PLIST := $(APP_CONTENTS)/Info.plist
INFO_PLIST_SRC := src/Info.plist

all: $(APP_BUNDLE)

$(APP_BUNDLE): $(EXECUTABLE) $(INFO_PLIST)

$(EXECUTABLE): $(SOURCES)
	mkdir -p $(APP_MACOS)
	$(SWIFT) $(SOURCES) $(FRAMEWORKS) -o $(EXECUTABLE)

$(INFO_PLIST): $(INFO_PLIST_SRC)
	mkdir -p $(APP_CONTENTS)
	cp $(INFO_PLIST_SRC) $(INFO_PLIST)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
