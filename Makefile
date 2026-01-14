UUID       ?= virtual-screen@hkfuertes
SRC_DIR    ?= applet
BUILD_DIR  ?= build
DIST_DIR   ?= dist

STAGE_DIR  := $(BUILD_DIR)/$(UUID)

USER_APPLETS_DIR := $(HOME)/.local/share/cinnamon/applets
USER_LINK        := $(USER_APPLETS_DIR)/$(UUID)

.PHONY: all build install uninstall package clean restart-cinnamon tree

all: build

tree:
	@echo "SRC:   $(SRC_DIR)/"
	@echo "BUILD: $(STAGE_DIR)/"
	@echo "LINK:  $(USER_LINK)"

build:
	@mkdir -p "$(STAGE_DIR)"
	@rsync -a --delete "$(SRC_DIR)/" "$(STAGE_DIR)/"

# Instala para tu usuario como symlink (comodo para desarrollar)
install: build
	@mkdir -p "$(USER_APPLETS_DIR)"
	@ln -sfn "$(abspath $(STAGE_DIR))" "$(USER_LINK)"
	@echo "Instalado (symlink): $(USER_LINK)"

uninstall:
	@rm -f "$(USER_LINK)"
	@echo "Eliminado: $(USER_LINK)"

# Zip listo para distribuir (contiene la carpeta UUID en la raiz del zip)
package: build
	@mkdir -p "$(DIST_DIR)"
	@(cd "$(BUILD_DIR)" && zip -qr "../$(DIST_DIR)/$(UUID).zip" "$(UUID)")
	@echo "Generado: $(DIST_DIR)/$(UUID).zip"

clean:
	@rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"

# Util durante desarrollo (reinicia Cinnamon sin cerrar sesion)
restart-cinnamon:
	@cinnamon --replace >/dev/null 2>&1 &
	@echo "Cinnamon reiniciado"


# ./hdmi-ipad-manager.sh on           # Crea + ON (2360x1640@60)
# ./hdmi-ipad-manager.sh on -w 1920 -h 1080  # Custom
# ./hdmi-ipad-manager.sh off          # OFF + cleanup + force=0
# ./hdmi-ipad-manager.sh change -w 3840 -h 2160  # Cambia y aplica
# ./hdmi-ipad-manager.sh status       # Estado
