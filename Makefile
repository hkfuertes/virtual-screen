UUID      ?= virtual-screen@hkfuertes
SRC_DIR   ?= virtual-screen@hkfuertes
BUILD_DIR ?= build
DIST_DIR  ?= dist

STAGE_DIR := $(BUILD_DIR)/$(UUID)

USER_APPLETS_DIR := $(HOME)/.local/share/cinnamon/applets
USER_LINK       := $(USER_APPLETS_DIR)/$(UUID)

SHELL := /bin/bash

.PHONY: all tree build install uninstall package clean restart-cinnamon dev

all: build

tree:
	@echo "UUID:  $(UUID)"
	@echo "SRC:   $(SRC_DIR)/"
	@echo "BUILD: $(STAGE_DIR)/"
	@echo "LINK:  $(USER_LINK)"

build:
	@mkdir -p "$(STAGE_DIR)"
	@rsync -a --delete "$(SRC_DIR)/" "$(STAGE_DIR)/"

# Install for current user as a symlink (good for development)
install: build
	@mkdir -p "$(USER_APPLETS_DIR)"
	@ln -sfn "$(abspath $(STAGE_DIR))" "$(USER_LINK)"
	@echo "Installed (symlink): $(USER_LINK)"

uninstall:
	@rm -f "$(USER_LINK)"
	@echo "Removed: $(USER_LINK)"

# Zip ready to distribute (UUID directory at the zip root)
package: build
	@mkdir -p "$(DIST_DIR)"
	@(cd "$(BUILD_DIR)" && zip -qr "../$(DIST_DIR)/$(UUID).zip" "$(UUID)")
	@echo "Built: $(DIST_DIR)/$(UUID).zip"

clean:
	@rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"

restart-cinnamon:
	@nohup cinnamon --replace >/dev/null 2>&1 &
	@echo "Cinnamon restarted"

dev: install restart-cinnamon
