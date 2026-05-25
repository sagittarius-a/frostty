# Frostty Build And Usage

This directory contains Frostty-specific scripts, examples, and rule catalogs.

## Build On macOS

Build a Frostty macOS app bundle:

```sh
./frostty/build-macos.sh --icon XrayImage
```

The script:

- builds Ghostty with the required Zig 0.15.2 toolchain;
- copies `zig-out/Ghostty.app` to `/private/tmp/Frostty.app`;
- patches the app metadata to `Frostty`;
- changes the bundle id to `com.mitchellh.ghostty.frostty`;
- renames the internal executable to `frostty`;
- selects one bundled alternate icon;
- creates starter Frostty config directories;
- signs the result ad hoc;
- verifies the signature.

The output app is:

```text
/private/tmp/Frostty.app
```

Run it with:

```sh
open /private/tmp/Frostty.app
```

Install it system-wide only when needed:

```sh
cp -R /private/tmp/Frostty.app /Applications/Frostty.app
```

## Build On Linux

The Linux path is intentionally minimal for now: it builds Ghostty's GTK binary
and copies it to `bin/frostty` inside a local prefix. The `frostty` executable
name makes the runtime load Frostty config paths by default and use a distinct
GTK application ID.

The script uses a local `zig 0.15.2` when available. If local `zig` is missing
or has the wrong version, it automatically retries inside the repo Nix dev
shell. It also installs the selected bundled icon under multiple hicolor sizes
and writes a Frostty desktop entry template for the `/opt/frostty` install path.

Build into `/tmp/frostty`:

```sh
./frostty/build-linux.sh
```

Or choose another prefix:

```sh
./frostty/build-linux.sh --prefix /tmp/frostty
```

Force a specific Zig binary if needed:

```sh
ZIG=/path/to/zig-0.15.2 ./frostty/build-linux.sh
```

Select a bundled icon:

```sh
./frostty/build-linux.sh --icon XrayImage
```

The output binary is:

```text
/tmp/frostty/bin/frostty
```

Run it directly:

```sh
/tmp/frostty/bin/frostty
```

Install the whole local prefix only when needed:

```sh
sudo mkdir -p /opt /usr/local/bin /usr/local/share/icons/hicolor /usr/local/share/applications
sudo rm -rf /opt/frostty
sudo cp -a /tmp/frostty /opt/frostty
sudo ln -sf /opt/frostty/bin/frostty /usr/local/bin/frostty
sudo cp -a /opt/frostty/share/icons/hicolor/. /usr/local/share/icons/hicolor/
sudo cp /opt/frostty/share/applications/com.mitchellh.ghostty.frostty.desktop /usr/local/share/applications/
sudo gtk-update-icon-cache /usr/local/share/icons/hicolor 2>/dev/null || true
sudo update-desktop-database /usr/local/share/applications 2>/dev/null || true
```

Current Linux limitations:

- GTK/system dependencies are still Ghostty's normal Linux build dependencies;
- the generated `bin/frostty` is a copied binary, not a wrapper.

## Linux Desktop Setup

Use this Frostty config on Linux:

```conf
class = com.mitchellh.ghostty.frostty

keybind = ctrl+shift+h=highlight_selection
keybind = ctrl+shift+backspace=clear_runtime_highlights

highlight-selection-foreground = #000000
highlight-selection-background = #ffaf00
```

The `class` value is required for clean coexistence with Ghostty on GTK. It
sets the Wayland application ID, DBus bus name, and X11 `WM_CLASS`. Without it,
Hyprland and GTK single-instance routing can treat Frostty and Ghostty as the
same application.

The generated desktop entry is:

```ini
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
```

Hyprland binds should launch Frostty directly:

```ini
bind = SUPER, Return, exec, frostty
bind = SUPER, Space, exec, frostty +toggle-quick-terminal
```

Do not bind `ghostty`, `/opt/frostty/bin/ghostty`, or
`gtk-launch com.mitchellh.ghostty` for Frostty.

## Icons

Only bundled alternate icons are supported.

List available icon names:

```sh
./frostty/build-macos.sh --list-icons
```

Current examples include:

```text
BlueprintImage
ChalkboardImage
GlassImage
HolographicImage
MicrochipImage
PaperImage
RetroImage
XrayImage
```

Select one:

```sh
./frostty/build-macos.sh --icon MicrochipImage
```

Arbitrary `.icns` or `.png` paths are intentionally not supported.

## Configuration

Frostty reads:

```text
~/.config/frostty/config
~/.config/frostty/patterns
```

`config` is the main config. `patterns` is optional and loaded after `config`.

Validate the effective Frostty config path explicitly:

```sh
/private/tmp/Frostty.app/Contents/MacOS/ghostty +validate-config --config-file="$HOME/.config/frostty/config"
```

A quick pattern-only setup:

```sh
mkdir -p ~/.config/frostty
cp frostty/kernel-patterns ~/.config/frostty/patterns
```

Runtime value tracking can be bound from the same config:

```conf
keybind = ctrl+shift+h=highlight_selection
keybind = ctrl+shift+backspace=clear_runtime_highlights

highlight-selection-foreground = #000000
highlight-selection-background = #ffaf00
```

Select a leaked pointer, hash, PID, or request ID, then trigger
`highlight_selection`. Frostty highlights exact future occurrences as a literal
token, without treating the selection as regex. The two color options control
the runtime highlight style.

## Examples

Render the screenshot fixture:

```sh
cat frostty/example.txt
```

Useful files:

- [HIGHLIGHTS.md](HIGHLIGHTS.md): large rule catalog.
- [example.txt](example.txt): sample output.
