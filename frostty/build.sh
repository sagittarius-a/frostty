#!/usr/bin/env bash

set -euo pipefail

APP_NAME="Frostty"
BUNDLE_ID="com.mitchellh.ghostty.frostty"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_APP="${FROSTTY_APP:-/private/tmp/${APP_NAME}.app}"
ICON_CHOICE="${FROSTTY_ICON:-}"
CONFIG_FILE="${FROSTTY_CONFIG_FILE:-${HOME}/.config/frostty/config}"
PLISTBUDDY="/usr/libexec/PlistBuddy"
WORKSPACE_ZIG="/nix/store/5l84a8nh45sc7fryfywvv0b6rfr8k0qc-zig-0.15.2/bin/zig"

usage() {
    cat <<EOF
Usage: ./frostty/build.sh [--icon NAME] [--app PATH] [--list-icons]

Options:
  --icon NAME          Bundled alternate icon name.
  --app PATH           Output .app path. Default: ${OUT_APP}
  --config PATH        Starter Frostty config file. Default: ${CONFIG_FILE}
  --list-icons         Print bundled alternate icon names and exit.

Environment:
  FROSTTY_ICON         Same as --icon. Must be a bundled alternate icon name.
  FROSTTY_APP          Same as --app.
  FROSTTY_CONFIG_FILE  Same as --config for starter file creation.
  ZIG                  Zig executable.
EOF
}

list_icons() {
    find "${ROOT_DIR}/macos/Assets.xcassets/Alternate Icons" \
        -maxdepth 1 \
        -name '*.imageset' \
        -type d \
        -exec basename {} .imageset \; | sort
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --icon)
            if [ "$#" -lt 2 ]; then
                echo "--icon requires a value" >&2
                exit 1
            fi
            ICON_CHOICE="$2"
            shift 2
            ;;
        --app)
            if [ "$#" -lt 2 ]; then
                echo "--app requires a value" >&2
                exit 1
            fi
            OUT_APP="$2"
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

if [ -n "${ZIG:-}" ]; then
    if [ ! -x "$ZIG" ] && ! command -v "$ZIG" >/dev/null 2>&1; then
        echo "configured Zig not found: ${ZIG}" >&2
        exit 1
    fi
elif [ -x "$WORKSPACE_ZIG" ]; then
    ZIG="$WORKSPACE_ZIG"
else
    ZIG="zig"
fi

if ! "$ZIG" version | grep -qx '0\.15\.2'; then
    echo "unsupported Zig version: $("$ZIG" version)" >&2
    echo "Ghostty currently requires Zig 0.15.2. Set ZIG=/path/to/zig-0.15.2." >&2
    exit 1
fi

cd "$ROOT_DIR"

echo "==> Building Ghostty macOS app"
"$ZIG" build install \
    -Doptimize=ReleaseFast \
    -Dxcframework-target=native \
    -Demit-macos-app=true

SOURCE_APP="${ROOT_DIR}/zig-out/Ghostty.app"
if [ ! -d "$SOURCE_APP" ]; then
    echo "build did not produce ${SOURCE_APP}" >&2
    exit 1
fi

echo "==> Creating ${OUT_APP}"
rm -rf "$OUT_APP"
cp -R "$SOURCE_APP" "$OUT_APP"

INFO_PLIST="${OUT_APP}/Contents/Info.plist"
RESOURCE_DIR="${OUT_APP}/Contents/Resources"
SOURCE_ICON="${RESOURCE_DIR}/Ghostty.icns"
TARGET_ICON="${RESOURCE_DIR}/${APP_NAME}.icns"

TMP_DIR=""
cleanup() {
    if [ -n "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

install_png_icon() {
    local png_path="$1"
    local iconset="$TMP_DIR/Frostty.iconset"

    mkdir -p "$iconset"
    sips -z 16 16 "$png_path" --out "$iconset/icon_16x16.png" >/dev/null
    sips -z 32 32 "$png_path" --out "$iconset/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$png_path" --out "$iconset/icon_32x32.png" >/dev/null
    sips -z 64 64 "$png_path" --out "$iconset/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$png_path" --out "$iconset/icon_128x128.png" >/dev/null
    sips -z 256 256 "$png_path" --out "$iconset/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$png_path" --out "$iconset/icon_256x256.png" >/dev/null
    sips -z 512 512 "$png_path" --out "$iconset/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$png_path" --out "$iconset/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$png_path" --out "$iconset/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$iconset" -o "$TARGET_ICON"
}

if [ -n "$ICON_CHOICE" ] && [ -f "${ROOT_DIR}/macos/Assets.xcassets/Alternate Icons/${ICON_CHOICE}.imageset/macOS-AppIcon-1024px.png" ]; then
    ICON_PNG="${ROOT_DIR}/macos/Assets.xcassets/Alternate Icons/${ICON_CHOICE}.imageset/macOS-AppIcon-1024px.png"
    echo "==> Generating icon from bundled alternate icon ${ICON_CHOICE}"
    TMP_DIR="$(mktemp -d)"
    install_png_icon "$ICON_PNG"
elif [ -n "$ICON_CHOICE" ]; then
    echo "unknown bundled icon: ${ICON_CHOICE}" >&2
    echo "available bundled icons:" >&2
    list_icons >&2
    exit 1
elif [ -f "$SOURCE_ICON" ]; then
    echo "==> No icon selected; reusing built app icon"
    cp "$SOURCE_ICON" "$TARGET_ICON"
else
    echo "missing icon: use --icon NAME" >&2
    exit 1
fi

echo "==> Patching bundle metadata"
"$PLISTBUDDY" -c "Set :CFBundleName ${APP_NAME}" "$INFO_PLIST"
"$PLISTBUDDY" -c "Set :CFBundleDisplayName ${APP_NAME}" "$INFO_PLIST"
"$PLISTBUDDY" -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$INFO_PLIST"
"$PLISTBUDDY" -c "Set :CFBundleIconFile ${APP_NAME}" "$INFO_PLIST"
"$PLISTBUDDY" -c "Set :CFBundleIconName ${APP_NAME}" "$INFO_PLIST"
mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "${HOME}/.config/frostty/themes"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "==> Creating starter config ${CONFIG_FILE}"
    cat > "$CONFIG_FILE" <<'EOF'
# Frostty pattern highlights.
# See frostty/HIGHLIGHTS.md in the repository for a larger rule catalog.

keybind = ctrl+shift+h=highlight_selection
keybind = ctrl+shift+backspace=clear_runtime_highlights

highlight-selection-foreground = #000000
highlight-selection-background = #ffaf00

highlight = name=critical-line type=line regex="\b(CRITICAL|FATAL|PANIC|panic|SIGSEGV|segmentation fault|core dumped)\b" fg="#ffffff" bg="#7f1d1d" priority=1000
highlight = name=error-line type=line regex="\b(ERROR|failed|denied|forbidden|unauthorized)\b" fg="#ffffff" bg="#4c1d1d" priority=900
highlight = name=secret-line type=line regex="\b(secret|password|passwd|token|api[_-]?key|private[_-]?key|credential|bearer|authorization)\b" fg="#ffffff" bg="#6d1f4f" priority=980
highlight = name=cve type=token regex="\bCVE-[0-9]{4}-[0-9]{4,7}\b" fg="#ffdf5d" bg="#3d2d00" priority=950
highlight = name=sha256 type=token regex="\b[A-Fa-f0-9]{64}\b" fg="#50fa7b" bg="#12351f" priority=900
highlight = name=ipv4 type=token regex="\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b" fg="#8be9fd" bg="#073642" priority=700
highlight = name=url type=token regex="\bhttps?://[^[:space:]\"'<>]+\b" fg="#8be9fd" bg="#073642" priority=800
highlight = name=aws-access-key type=token regex="\b(?:AKIA|ASIA)[A-Z0-9]{16}\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=github-token type=token regex="\bgh[pousr]_[A-Za-z0-9_]{36,255}\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=jwt type=token regex="\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b" fg="#ff5555" bg="#3f1111" priority=1000
EOF
fi

echo "==> Signing ${OUT_APP}"
codesign --force --deep --sign - "$OUT_APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$OUT_APP"

echo "==> Done"
echo "$OUT_APP"
echo
echo "Install to /Applications if needed:"
echo "  cp -R \"${OUT_APP}\" \"/Applications/${APP_NAME}.app\""
