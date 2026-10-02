# Window switcher for Omarchy

A fuzzy-search window switcher overlay for the Omarchy shell. It lists every
open Hyprland window (most recently used first) with its app icon, title, app
name, and workspace. Type to filter, then press Enter to focus.

## Install

```bash
omarchy plugin add https://github.com/prov4/omarchy-window-switcher.git --enable
```

Then bind a key in `~/.config/hypr/bindings.lua`, for example Alt+Tab:

```lua
hl.unbind("ALT + TAB")
o.bind("ALT + TAB", "Window switcher", "omarchy-shell shell toggle josip.window-switcher")
```

## Remove

```bash
omarchy plugin remove josip.window-switcher
```

Then delete the keybinding you added to `~/.config/hypr/bindings.lua` (and the
`hl.unbind` line, to restore Omarchy's default Alt+Tab). The plugin never edits
your config files itself.

## Keys

| Key | Action |
|-----|--------|
| type | Fuzzy filter by app name and title (space-separated terms all must match) |
| Tab / Down / Ctrl+N / Ctrl+J | Next window |
| Shift+Tab / Up / Ctrl+P / Ctrl+K | Previous window |
| PageUp / PageDown | Jump a page |
| Enter / click | Focus the selected window |
| Backspace / Ctrl+Backspace / Ctrl+U | Delete char / word / clear |
| Esc | Clear filter, or close |

The previously focused window is preselected, so open + Enter jumps back to it.

## Requirements

Omarchy with the Quickshell-based shell (Quattro) and Hyprland. No external
dependencies beyond `hyprctl`, which ships with Hyprland.

## License

MIT
