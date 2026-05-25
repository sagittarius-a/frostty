#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PREFIX="${FROSTTY_PREFIX:-/tmp/frostty}"
CONFIG_FILE="${FROSTTY_CONFIG_FILE:-${HOME}/.config/frostty/config}"
ICON_CHOICE="${FROSTTY_ICON:-XrayImage}"
ORIGINAL_ARGS=("$@")

usage() {
    cat <<EOF
Usage: ./frostty/build-linux.sh [--prefix PATH] [--config PATH] [--icon NAME] [--list-icons]

Options:
  --prefix PATH        Local install prefix. Default: ${PREFIX}
  --config PATH        Starter Frostty config file. Default: ${CONFIG_FILE}
  --icon NAME          Bundled alternate icon name. Default: ${ICON_CHOICE}
  --list-icons         Print bundled alternate icon names and exit.

Environment:
  FROSTTY_PREFIX       Same as --prefix.
  FROSTTY_CONFIG_FILE  Same as --config for starter file creation.
  FROSTTY_ICON         Same as --icon. Must be a bundled alternate icon name.
  ZIG                  Zig 0.15.2 executable. If unset, the script falls back
                       to the repo Nix dev shell when local zig is missing or
                       has the wrong version.
EOF
}

list_icons() {
    find "${ROOT_DIR}/macos/Assets.xcassets/Alternate Icons" \
        -maxdepth 1 \
        -name '*.imageset' \
        -type d \
        -exec basename {} .imageset \; | sort
}

has_zig_0_15_2() {
    local zig_bin="$1"

    if ! command -v "$zig_bin" >/dev/null 2>&1 && [ ! -x "$zig_bin" ]; then
        return 1
    fi

    "$zig_bin" version | grep -qx '0\.15\.2'
}

run_in_nix_shell() {
    if [ "${FROSTTY_LINUX_BUILD_IN_NIX:-}" = "1" ]; then
        echo "Zig 0.15.2 is still unavailable inside the Nix dev shell" >&2
        exit 1
    fi

    if ! command -v nix >/dev/null 2>&1; then
        echo "configured Zig not found or not Zig 0.15.2" >&2
        echo "Install Zig 0.15.2, set ZIG=/path/to/zig-0.15.2, or install Nix." >&2
        exit 1
    fi

    echo "==> Local Zig is not 0.15.2; retrying inside Nix dev shell"
    cd "$ROOT_DIR"
    exec nix \
        --extra-experimental-features 'nix-command flakes' \
        develop "$ROOT_DIR" \
        --command env FROSTTY_LINUX_BUILD_IN_NIX=1 "${SCRIPT_DIR}/build-linux.sh" "${ORIGINAL_ARGS[@]}"
}

create_starter_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    mkdir -p "${HOME}/.config/frostty/themes"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "==> Creating starter config ${CONFIG_FILE}"
        cp "${SCRIPT_DIR}/starter-config" "$CONFIG_FILE"
    fi
}

install_icon() {
    local icon_png="${ROOT_DIR}/macos/Assets.xcassets/Alternate Icons/${ICON_CHOICE}.imageset/macOS-AppIcon-1024px.png"
    local sizes=(16 24 32 48 64 128 256 512 1024)

    if [ ! -f "$icon_png" ]; then
        echo "unknown bundled icon: ${ICON_CHOICE}" >&2
        echo "available bundled icons:" >&2
        list_icons >&2
        exit 1
    fi

    echo "==> Installing Frostty icon ${ICON_CHOICE}"
    for size in "${sizes[@]}"; do
        local icon_dir="${PREFIX}/share/icons/hicolor/${size}x${size}/apps"
        local icon_target="${icon_dir}/com.mitchellh.ghostty.frostty.png"

        mkdir -p "$icon_dir"
        if command -v magick >/dev/null 2>&1; then
            magick "$icon_png" -resize "${size}x${size}" "$icon_target"
        elif command -v convert >/dev/null 2>&1; then
            convert "$icon_png" -resize "${size}x${size}" "$icon_target"
        else
            cp "$icon_png" "$icon_target"
        fi
    done
}

install_desktop_entry() {
    local desktop_dir="${PREFIX}/share/applications"
    local desktop_file="${desktop_dir}/com.mitchellh.ghostty.frostty.desktop"

    echo "==> Installing Frostty desktop entry template"
    mkdir -p "$desktop_dir"
    cat >"$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Frostty
GenericName=Terminal Emulator
Comment=Ghostty fork tailored for vulnerability research
Exec=/usr/local/bin/frostty
Icon=/opt/frostty/share/icons/hicolor/512x512/apps/com.mitchellh.ghostty.frostty.png
Terminal=false
Categories=System;TerminalEmulator;
Keywords=terminal;shell;prompt;command;frostty;ghostty;
StartupNotify=true
StartupWMClass=com.mitchellh.ghostty.frostty
DBusActivatable=false
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            if [ "$#" -lt 2 ]; then
                echo "--prefix requires a value" >&2
                exit 1
            fi
            PREFIX="$2"
            shift 2
            ;;
        --config)
            if [ "$#" -lt 2 ]; then
                echo "--config requires a value" >&2
                exit 1
            fi
            CONFIG_FILE="$2"
            shift 2
            ;;
        --icon)
            if [ "$#" -lt 2 ]; then
                echo "--icon requires a value" >&2
                exit 1
            fi
            ICON_CHOICE="$2"
            shift 2
            ;;
        --list-icons)
            list_icons
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ "$(uname -s)" != "Linux" ]; then
    echo "build-linux.sh must be run on Linux" >&2
    exit 1
fi

if [ -n "${ZIG:-}" ]; then
    if ! has_zig_0_15_2 "$ZIG"; then
        echo "unsupported Zig version from ZIG=${ZIG}: $("$ZIG" version 2>/dev/null || echo unavailable)" >&2
        echo "Ghostty currently requires Zig 0.15.2. Unset ZIG to allow the Nix fallback." >&2
        exit 1
    fi
elif has_zig_0_15_2 zig; then
    ZIG="zig"
else
    run_in_nix_shell
fi

cd "$ROOT_DIR"

echo "==> Building Ghostty Linux binary"
"$ZIG" build install \
    --prefix "$PREFIX" \
    -Doptimize=ReleaseFast \
    -Demit-macos-app=false

GHOSTTY_BIN="${PREFIX}/bin/ghostty"
FROSTTY_BIN="${PREFIX}/bin/frostty"
if [ ! -x "$GHOSTTY_BIN" ]; then
    echo "build did not produce ${GHOSTTY_BIN}" >&2
    exit 1
fi

echo "==> Creating ${FROSTTY_BIN}"
cp "$GHOSTTY_BIN" "$FROSTTY_BIN"
chmod +x "$FROSTTY_BIN"

install_icon
install_desktop_entry
create_starter_config

echo "==> Done"
echo "$FROSTTY_BIN"
echo "${PREFIX}/share/icons/hicolor/512x512/apps/com.mitchellh.ghostty.frostty.png"
echo "${PREFIX}/share/applications/com.mitchellh.ghostty.frostty.desktop"
echo
echo "Run locally:"
echo "  \"${FROSTTY_BIN}\""
echo
echo "Install to /opt if needed:"
echo "  sudo mkdir -p /opt /usr/local/bin /usr/local/share/icons/hicolor /usr/local/share/applications"
echo "  sudo rm -rf /opt/frostty"
echo "  sudo cp -a \"${PREFIX}\" /opt/frostty"
echo "  sudo ln -sf /opt/frostty/bin/frostty /usr/local/bin/frostty"
echo "  sudo cp -a /opt/frostty/share/icons/hicolor/. /usr/local/share/icons/hicolor/"
echo "  sudo cp /opt/frostty/share/applications/com.mitchellh.ghostty.frostty.desktop /usr/local/share/applications/"
echo "  sudo gtk-update-icon-cache /usr/local/share/icons/hicolor 2>/dev/null || true"
echo "  sudo update-desktop-database /usr/local/share/applications 2>/dev/null || true"
