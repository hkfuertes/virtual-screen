#!/bin/bash
#
# install-virtual-display.sh
# Installs virtual display scripts and configures Sunshine.
# Usage: sudo bash scripts/install-virtual-display.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="/opt/sunshine-virtual-display"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Run with sudo: sudo bash $0"
        exit 1
    fi
}

check_dependencies() {
    local missing=()
    for cmd in cvt xrandr; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        log "Install with: sudo apt install x11-xserver-utils"
        exit 1
    fi
}

detect_dummy_output() {
    local real_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$real_user" | cut -d: -f6)
    local xauth="${user_home}/.Xauthority"

    log "Detecting dummy plug output via xrandr..."

    local primary
    primary=$(DISPLAY=:0 XAUTHORITY="$xauth" xrandr | grep " connected primary" | awk '{print $1}')

    # First connected non-primary output = dummy plug
    VIRTUAL_OUTPUT=$(DISPLAY=:0 XAUTHORITY="$xauth" xrandr \
        | grep " connected" \
        | grep -v "^${primary} " \
        | awk '{print $1}' \
        | head -1)

    if [[ -z "$VIRTUAL_OUTPUT" ]]; then
        error "No connected external output found — is the dummy plug inserted?"
        exit 1
    fi

    # Compute 0-based index of the output in xrandr's full list (Sunshine needs a number)
    local index=0
    while IFS= read -r line; do
        local name
        name=$(echo "$line" | awk '{print $1}')
        [[ "$name" == "$VIRTUAL_OUTPUT" ]] && break
        ((index++))
    done < <(DISPLAY=:0 XAUTHORITY="$xauth" xrandr | grep -E "^[A-Za-z]")

    VIRTUAL_OUTPUT_INDEX="$index"
    log "Found dummy output: $VIRTUAL_OUTPUT (Sunshine index: $VIRTUAL_OUTPUT_INDEX)"
}

install_scripts() {
    mkdir -p "$INSTALL_DIR"

    for script in activate-virtual-display.sh deactivate-virtual-display.sh; do
        local src="${REPO_ROOT}/scripts/${script}"
        [[ -f "$src" ]] || { error "Not found: $src"; exit 1; }
        cp "$src" "${INSTALL_DIR}/${script}"
        chmod +x "${INSTALL_DIR}/${script}"
        log "Installed ${script}"
    done

    echo "$VIRTUAL_OUTPUT" > "${INSTALL_DIR}/output_name"
    log "Saved output name: $VIRTUAL_OUTPUT → ${INSTALL_DIR}/output_name"
}

configure_sunshine() {
    local real_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$real_user" | cut -d: -f6)
    local conf="${user_home}/.config/sunshine/sunshine.conf"

    mkdir -p "$(dirname "$conf")"
    touch "$conf"

    set_conf_key() {
        local key="$1" value="$2" file="$3"
        if grep -qE "^#?[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null; then
            sed -i "s|^#\?[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
        else
            echo "${key} = ${value}" >> "$file"
        fi
    }

    local prep_json="[{\"do\":\"${INSTALL_DIR}/activate-virtual-display.sh\",\"undo\":\"${INSTALL_DIR}/deactivate-virtual-display.sh\",\"elevated\":false}]"

    set_conf_key "output_name"     "$VIRTUAL_OUTPUT_INDEX" "$conf"
    set_conf_key "global_prep_cmd" "$prep_json"            "$conf"

    chown "$real_user" "$conf"
    log "Sunshine config updated: output_name=$VIRTUAL_OUTPUT_INDEX, global_prep_cmd set"
}

main() {
    echo
    log "========================================="
    log "  Virtual Display Installer"
    log "========================================="
    echo

    check_root
    check_dependencies
    detect_dummy_output
    install_scripts
    configure_sunshine

    echo
    log "========================================="
    log "  Done!"
    log "========================================="
    echo
    log "Restart Sunshine to apply:"
    echo "  systemctl --user restart sunshine"
    echo
    log "Session log: \${XDG_RUNTIME_DIR}/virtual-display.log"
    echo
}

main "$@"
