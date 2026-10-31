# matrix.audio

## Matrix FX (2026-10-31)

Cloned from omarchy.audio with `omarchy plugin clone` and patched with the same
effect as matrix.clock's calendar:

- Icon press: a short CRT flicker on the bar icon.
- Open: the card unfolds from a thin line (170 ms), a Matrix rain/scanline
  reveals the content, then the biggest labels decode out of glyphs.
- Close: rain dissolve, then a CRT squash to a line plus a brief flash, then hide.
- Shared code is in fx/ (MatrixRain, ScrambleText, MatrixGate, Glyphs.js,
  PanelFx.qml), copied from matrix.clock.

Setting `matrixFx` in this widget's shell.json settings: "theme" (default,
only on the matrix theme), "always", or "off".

Revert: set the id in ~/.config/omarchy/shell.json back to "omarchy.audio"
(or restore everything with
`cp ~/.config/omarchy/shell.json.bak-pre-panelfx ~/.config/omarchy/shell.json`),
