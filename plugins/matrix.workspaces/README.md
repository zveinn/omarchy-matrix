# matrix.workspaces – Matrix workspace indicators

Clone of the built-in `omarchy.workspaces`.

## Effects
- **Workspace switch**: a glyph streak shoots from the old to the new indicator (220 ms), the new number decodes from katakana (300 ms) with a falling drop (280 ms).
- **Hover**: brief glitch on the hovered number (130 ms).

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
- Built-in widget back: edit `~/.config/omarchy/shell.json` and change `"id": "matrix.workspaces"` back to `"omarchy.workspaces"`, then `omarchy-restart-shell`.
- After editing QML, run `omarchy-restart-shell` (hot reload does not re-register IPC handlers / cached components).