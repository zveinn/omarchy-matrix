# matrix.clock – Matrix clock + calendar

Clone of the built-in `omarchy.clock` (keeps the `omarchy.clock` IPC target, e.g. `omarchy-shell omarchy.clock toggle`).

## Effects
- **Calendar open**: card unfolds from a thin line at the bar edge (~170 ms) while a green rain reveal sweeps down with a scanline (~430 ms); the hero date (440 ms) and month label (400 ms) decode from katakana.
- **Calendar close**: rain dissolve (190 ms) then CRT switch-off: card squashes to a line (150 ms) with a soft green flash.
- **Clock label**: decodes from glyphs every time the text changes (each minute) and on click; short glitch on hover.
- **Month navigation**: month label scrambles (240 ms).

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
- Built-in widget back: edit `~/.config/omarchy/shell.json` and change `"id": "matrix.clock"` back to `"omarchy.clock"`, then `omarchy-restart-shell`.
- After editing QML, run `omarchy-restart-shell` (hot reload does not re-register IPC handlers / cached components).