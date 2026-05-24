# Frostty Build And Usage

This directory contains Frostty-specific scripts, examples, and rule catalogs.

## Build

Build a Frostty macOS app bundle:

```sh
./frostty/build.sh --icon XrayImage
```

The script:

- builds Ghostty with the required Zig 0.15.2 toolchain;
- copies `zig-out/Ghostty.app` to `/private/tmp/Frostty.app`;
- patches the app metadata to `Frostty`;
- changes the bundle id to `com.mitchellh.ghostty.frostty`;
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

## Icons

Only bundled alternate icons are supported.

List available icon names:

```sh
./frostty/build.sh --list-icons
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
./frostty/build.sh --icon MicrochipImage
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
