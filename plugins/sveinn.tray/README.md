# sveinn.tray – Matrix system tray

Clone of the built-in `omarchy.tray`.

## Effects
- **Icon click/press**: icon flickers (~160 ms) and a glyph ring burst fires from the icon (380 ms; clipped to bar height).
- **Tray menu open**: rows type in from the left with a print-head bar (200–450 ms depending on row count), scanline + rain reveal; submenus re-print.
- **Tray menu close**: quick rain dissolve (150 ms).

## Test IPC
`omarchy-shell sveinn.trayfx list` · `omarchy-shell sveinn.trayfx click 0` · `omarchy-shell sveinn.trayfx close`

## Theme gating
Effects only run while `~/.local/state/omarchy/current/theme.name` is `matrix` (watched live by `fx/MatrixGate.qml`).
Override per bar entry in `~/.config/omarchy/shell.json` with `"matrixFx": "theme"` (default), `"always"` or `"off"`.
Nothing animates when idle; overlays and rain Loaders exist only while an effect runs.

## Shared fx library (`fx/`)
- `Glyphs.js` – katakana/digit glyph set + decode helper
- `MatrixGate.qml` – theme watcher
- `ScrambleText.qml` – per-character decode/glitch text overlay (Hurmit Nerd Font + Noto Sans CJK JP)
- `MatrixRain.qml` – short-lived rain reveal/dissolve overlay
- `GlyphBurst.qml` – ring + glyph particle burst

## Revert
- Built-in widget back: edit `~/.config/omarchy/shell.json` and change `"id": "sveinn.tray"` back to `"omarchy.tray"`
  (or `cp ~/.config/omarchy/shell.json.bak-pre-barfx ~/.config/omarchy/shell.json` to revert all three), then `omarchy-restart-shell`.
- Pristine (no-fx) clone: `~/.cache/barfx/plugins-pristine-clones/sveinn.tray`.
- Backup copy of this plugin: `~/code/tools/dotfiles/themes-backup/matrix-2026-10-31/plugins/sveinn.tray`.
- After editing QML, run `omarchy-restart-shell` (hot reload does not re-register IPC handlers / cached components).