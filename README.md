# Frostty

Frostty is a quick and dirty hack of [Ghostty](GHOSTTY.md), tailored for
vulnerability research.

The goal is not to fork Ghostty into a general-purpose terminal. The goal is to
keep Ghostty's speed and native macOS behavior while adding low-friction visual
triage features for exploit development, kernel debugging, log review, etc. One
can also hack this hack for a different usage.

_**NOTE**_: Tested on macOS only. Do not expect anything from this project, I
just published it for fun. It will mess with colorschemes of your favorite
terminal applications.

![Fancy screenshot](frostty/example.png)

## Current Features

Frostty currently adds persistent regex-based highlights for visible terminal
output.

Rules are configured with the normal Ghostty config syntax:

```conf
highlight = name=sha256 type=token regex="\b[A-Fa-f0-9]{64}\b" fg="#50fa7b" bg="#12351f" priority=900
highlight = name=kernel-oops type=line regex="\b(BUG:|Oops:|Kernel panic)\b" fg="#ffffff" bg="#7f1d1d" priority=1100
```

Supported rule modes:

- `type=token`: highlights the exact regex match.
- `type=line`: highlights the whole logical line when the regex matches.

Supported rule fields:

- `name`: stable rule identifier.
- `regex`: Oniguruma regex.
- `fg`: optional foreground override.
- `bg`: optional background override.
- `priority`: higher priority wins on overlap.
- `enabled`: set to `false` to keep a disabled rule in config.

The renderer scans visible logical lines, including soft-wrapped rows. This
means long IOCs such as SHA-256 values can still match when wrapped across
multiple visual rows.

## Configuration

Frostty reads:

```text
~/.config/frostty/config
~/.config/frostty/patterns
```

`config` is the main Frostty config (identical to Ghostty). `patterns` is optional
and loaded after `config`, which is useful for keeping large highlight rule sets
separate.

Theme lookup also checks:

```text
~/.config/frostty/themes
```

before falling back to Ghostty's normal user and bundled theme locations.

## Examples

- [frostty/HIGHLIGHTS.md](frostty/HIGHLIGHTS.md): larger catalog of example
  highlight rules for vulnerability research.
- [frostty/kernel-patterns](frostty/kernel-patterns): focused kernel crash and
  pointer rules.
- [frostty/example.txt](frostty/example.txt): synthetic terminal output for
  screenshots and visual checks.

## Building

Use the Frostty build wrapper:

```sh
./frostty/build.sh --icon XrayImage
```

By default, it is using an alternative icon so it is easy to distinguish Frostty
from Ghostty in Dock and application switcher.

![Switcher preview](frostty/task-switcher.png)

Build and packaging details are documented in [frostty/README.md](frostty/README.md).

## Limitations

Frostty is intentionally packaged as a lightweight local app wrapper around the
Ghostty macOS bundle.

The app is renamed and uses a distinct bundle identifier:

```text
CFBundleName = Frostty
CFBundleIdentifier = com.mitchellh.ghostty.frostty
```

However, the internal executable is still Ghostty's executable:

```text
CFBundleExecutable = ghostty
```

This is good enough for local vulnerability research workflows and keeps the
hack small, but it is not a fully independent macOS product identity. Finder,
Dock, and LaunchServices can distinguish Frostty from Ghostty, but System
Settings permissions and TCC state may still behave inconsistently depending on
signature, install path, executable name, and rebuild history.

The build script signs the app ad hoc and writes it to `/private/tmp` by
default. Rebuilt copies may be treated by macOS as new local apps. A stronger
separation would require renaming the internal executable, updating
`CFBundleExecutable`, auditing Ghostty-specific runtime identifiers, and signing
with a stable identity.

## Upstream

The original Ghostty README has been preserved as [GHOSTTY.md](GHOSTTY.md).
