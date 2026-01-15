# Virtual Screen Cinnamon Applet Makefile

UUID     := virtual-screen@hkfuertes
SRC_DIR  := $(UUID)
BUILD_DIR = build
DIST_DIR  = dist

STAGE_DIR = $(BUILD_DIR)/$(UUID)
APPLETS_DIR = $(HOME)/.local/share/cinnamon/applets
LINK_TARGET = $(APPLETS_DIR)/$(UUID)

SHELL := /bin/bash

# Default target
.PHONY: all
all: install

# Show project structure
.PHONY: info
info:
	@echo "=== Virtual Screen Applet ==="
	@echo "UUID:     $(UUID)"
	@echo "Source:   $(SRC_DIR)/"
	@echo "Build:    $(STAGE_DIR)/"
	@echo "Link:     $(LINK_TARGET)"
	@echo "Applets:  $(APPLETS_DIR)/"

# Build the applet
.PHONY: build
build:
	@mkdir -p "$(STAGE_DIR)"
	@rsync -a --delete "$(SRC_DIR)/" "$(STAGE_DIR)/"
	@echo "Built: $(STAGE_DIR)"

# Install as symlink (for development)
.PHONY: install
install: build
	@mkdir -p "$(APPLETS_DIR)"
	@ln -sfn "$(abspath $(STAGE_DIR))" "$(LINK_TARGET)"
	@echo "Installed: $(LINK_TARGET)"

# Quick install without rebuild (for development)
.PHONY: quick-install
quick-install:
	@mkdir -p "$(APPLETS_DIR)"
	@ln -sfn "$(abspath $(SRC_DIR))" "$(LINK_TARGET)"
	@echo "Quick installed: $(LINK_TARGET)"

# Uninstall the applet
.PHONY: uninstall
uninstall:
	@rm -f "$(LINK_TARGET)"
	@echo "Uninstalled: $(LINK_TARGET)"

# Create distributable package
.PHONY: package
package: build
	@mkdir -p "$(DIST_DIR)"
	@(cd "$(BUILD_DIR)" && zip -qr "../$(DIST_DIR)/$(UUID).zip" "$(UUID)")
	@echo "Packaged: $(DIST_DIR)/$(UUID).zip"

# Clean build artifacts
.PHONY: clean
clean:
	@rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
	@echo "Cleaned build artifacts"

# Restart Cinnamon
.PHONY: restart
restart:
	@nohup cinnamon --replace >/dev/null 2>&1 &
	@echo "Cinnamon restarted"

# Development workflow: install and restart
.PHONY: dev
dev: install restart

# Quick development: quick-install and restart
.PHONY: qdev
qdev: quick-install restart

# Check that all required files exist and are executable
.PHONY: check
check:
	@echo "Checking required files..."
	@test -f "$(SRC_DIR)/applet.js" || (echo "ERROR: applet.js not found" && exit 1)
	@test -f "$(SRC_DIR)/metadata.json" || (echo "ERROR: metadata.json not found" && exit 1)
	@test -x "$(SRC_DIR)/bin/x11-manager.sh" || (echo "ERROR: x11-manager.sh not executable" && exit 1)
	@test -x "$(SRC_DIR)/bin/sunshine-manager.sh" || (echo "ERROR: sunshine-manager.sh not executable" && exit 1)
	@echo "All checks passed ✓"

# Test basic functionality
.PHONY: test
test: check
	@echo "Testing basic functionality..."
	@"$(SRC_DIR)/bin/x11-manager.sh" status >/dev/null 2>&1 || (echo "ERROR: x11-manager.sh status failed" && exit 1)
	@"$(SRC_DIR)/bin/sunshine-manager.sh" status >/dev/null 2>&1 || (echo "ERROR: sunshine-manager.sh status failed" && exit 1)
	@echo "Basic tests passed ✓"

# Show available commands
.PHONY: help
help:
	@echo "Virtual Screen Cinnamon Applet - Makefile Commands"
	@echo ""
	@echo "Development:"
	@echo "  make dev          - Install and restart Cinnamon (recommended for development)"
	@echo "  make qdev         - Quick install and restart (no rebuild)"
	@echo "  make install      - Install as symlink after build"
	@echo "  make quick-install- Install as direct symlink (faster for development)"
	@echo "  make restart      - Restart Cinnamon desktop"
	@echo ""
	@echo "Building:"
	@echo "  make build        - Build the applet to build/ directory"
	@echo "  make package      - Create distributable .zip package"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make uninstall    - Remove installed applet"
	@echo "  make check        - Validate all required files exist"
	@echo "  make test         - Run basic functionality tests"
	@echo ""
	@echo "Information:"
	@echo "  make info         - Show project structure and paths"
	@echo "  make help         - Show this help message"
	@echo ""
	@echo "Default: make (runs install)"