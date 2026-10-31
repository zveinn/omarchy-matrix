-- ░▒▓ MATRIX ▓▒░
-- Solid windows over live digital rain. Only the active window has a border:
-- on focus a ring of scrambling glyphs runs around its edge (rain/FocusFx.qml)
-- and the green #00ff41 border only appears once it has finished.

local active_border = "rgba(00ff41ff)"

local inactive_border = "rgba(00000000)"

hl.config({
  general = {
    border_size = 1,
    col = {
      -- Hidden by default: the focus handler below reveals the green border
      -- per window only after the glyph-ring animation has finished, so it
      -- never flashes before the animation starts.
      active_border = inactive_border,
      inactive_border = inactive_border,
    },
  },

  group = {
    col = {
      border_active = inactive_border,  -- glyph ring replaces it
      border_inactive = inactive_border,
    },
    groupbar = {
      font_family = "Hurmit Nerd Font",
      text_color = "rgb(00ff41)",
      text_color_inactive = "rgba(5f9f6caa)",
      col = {
        active = "rgba(003b00cc)",
        inactive = "rgba(000a0299)",
      },
    },
  },

  decoration = {
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    fullscreen_opacity = 1.0,

    blur = {
      enabled = true,
      size = 2,
      passes = 1,
      vibrancy = 0.2,
      noise = 0.025, -- a touch of CRT grain
    },

    shadow = {
      enabled = false,
    },
  },
})

-- Curves: hard, digital, no rubber-banding.
hl.curve("matrixSnap", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("matrixOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("matrixIn", { type = "bezier", points = { { 0.7, 0 }, { 0.84, 0 } } })
hl.curve("matrixFall", { type = "bezier", points = { { 0.3, 0 }, { 0.15, 1 } } })
hl.curve("matrixLinear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

-- Motion
hl.animation({ leaf = "windows", enabled = true, speed = 3.2, bezier = "matrixSnap" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.0, bezier = "matrixSnap", style = "popin 70%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.0, bezier = "matrixIn", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.0, bezier = "matrixOut" })
hl.animation({ leaf = "border", enabled = true, speed = 0.6, bezier = "matrixLinear" })
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "matrixOut" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.5, bezier = "matrixOut" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "matrixIn" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 3, bezier = "matrixOut" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 3, bezier = "matrixOut" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "matrixSnap" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "matrixSnap", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "matrixIn", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "matrixOut" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.8, bezier = "matrixIn" })
-- Workspaces rain down like falling code.
-- plain fade: windows stay put so the glyph decode lands exactly on them
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "matrixOut", style = "fade" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.2, bezier = "matrixSnap", style = "slidevert" })

-- ─── SMART GAPS + BORDERS ──────────────────────────────────────────────────
-- A lone tiled window, or a maximized / fullscreen one, fills the screen edge to
-- edge with no gaps and no border. Everything else gets padding (looknfeel.lua).
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, border_size = 0 })
hl.window_rule({ match = { fullscreen = true }, border_size = 0 })

-- Solid windows: cancel Omarchy's default 0.985/0.96 opacity rule.
hl.window_rule({ match = { class = ".*" }, opacity = "1.0 override 1.0 override 1.0 override" })

-- ─── GLYPH-RING BORDER ──────────────────────────────────────────────────────
-- The active border IS a ring of tiny scrambling katakana, drawn by the
-- matrix-rain quickshell process (rain/FocusFx.qml) in the gap just OUTSIDE the
-- focused window, so it never covers content. Hyprland's own border is kept
-- invisible. Here we feed the overlay the active window's geometry: "fire" on a
-- focus change (ring races in from the top-left), "move" when the same window
-- moves/resizes, "hide" for lone tiled / fullscreen windows or empty workspaces.
local RAIN_QML = os.getenv("HOME") .. "/.config/omarchy/themes/matrix/rain/shell.qml"

-- Effects are signalled by appending a line to a file the rain process watches
-- (inotify): no process spawn per event, so the visuals stay in sync.
local FX_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/matrix-fx"
local fx_writes = 0
do local f = io.open(FX_FILE, "w"); if f then f:close() end end
function matrix_fx_send(line)
  fx_writes = fx_writes + 1
  local f = io.open(FX_FILE, fx_writes > 400 and "w" or "a")
  if fx_writes > 400 then fx_writes = 1 end
  if f then f:write(line, "\n"); f:close() end
end
local function ipc(args) matrix_fx_send("ring " .. args) end

-- Every window on a visible workspace gets a ring, except on workspaces with a
-- fullscreen window, and a lone tiled window gets none. One "ring list" line
-- carries them all, bottom-to-top in z-order:
--   addr x y w h floating active [mx my mw mh ...]   (entries split by ";")
-- the m-rects are floating windows stacked above a floating one (cut out of its ring).
local last_key = nil
local last_float = {}            -- address -> floating, to spot float toggles
local on_float_toggle = nil      -- set by the transitions block below
local B = 9
local function update(focus_changed)
  local aw = hl.get_active_window()
  local aaddr = nil
  pcall(function()
    aaddr = tostring(aw.address)
    local fl = aw.floating and true or false
    local prev = last_float[aaddr]
    last_float[aaddr] = fl
    if prev ~= nil and prev ~= fl and on_float_toggle then on_float_toggle(aw) end
  end)
  local ok, line = pcall(function()
    local vis = {}
    for _, m in ipairs(hl.get_monitors()) do
      if m.active_workspace then vis[m.active_workspace.id] = true end
      if m.special_workspace then vis[m.special_workspace.id] = true end
    end
    local wins, tiled, fs = {}, {}, {}
    for _, x in ipairs(hl.get_windows()) do
      if x.workspace and vis[x.workspace.id] and x.mapped ~= false and not x.hidden then
        local id = x.workspace.id
        wins[#wins + 1] = x
        if x.fullscreen and x.fullscreen ~= 0 then fs[id] = true end
        if not x.floating then tiled[id] = (tiled[id] or 0) + 1 end
      end
    end
    local parts = {}
    for i, x in ipairs(wins) do
      local id = x.workspace.id
      if not fs[id] and (x.floating or (tiled[id] or 0) > 1) then
        local ad = tostring(x.address)
        local X, Y, W, H = x.at.x, x.at.y, x.size.x, x.size.y
        local e = string.format("%s %d %d %d %d %d %d", ad, X, Y, W, H, x.floating and 1 or 0, ad == aaddr and 1 or 0)
        if x.floating then
          local n = 0
          for j = i + 1, #wins do
            local o = wins[j]
            if n < 4 and o.floating and o.workspace.id == id then
              local ax, ay, ow, oh = o.at.x, o.at.y, o.size.x, o.size.y
              if ax < X + W + B and ax + ow > X - B and ay < Y + H + B and ay + oh > Y - B then
                e = e .. string.format(" %d %d %d %d", ax, ay, ow, oh); n = n + 1
              end
            end
          end
        end
        parts[#parts + 1] = e
      end
    end
    return table.concat(parts, ";")
  end)
  if not ok then line = "" end
  if line == last_key then return end
  last_key = line
  ipc("list " .. line)
end

-- Hyprland's border stays invisible: wipe any per-window colour left behind by
-- older versions of this theme (they made the green line flash on alt+tab).
local HIDDEN = "rgba(00000000)"
local function hide_border(w)
  pcall(hl.dispatch, hl.dsp.window.set_prop({ prop = "active_border_color", value = HIDDEN, window = w }))
end
for _, w in ipairs(hl.get_windows()) do hide_border(w) end

hl.on("window.active", function(w)
  if w then hide_border(w) end
  update(true)
end)
-- the rain process calls this on startup so the ring is redrawn after a restart
matrix_ring_resync = function() last_key = nil end
-- cheap in-compositor poll: only spawns an IPC call when something changed
hl.timer(function() update(false) end, { timeout = 16, type = "repeat" })

-- ─── MATRIX TRANSITIONS ─────────────────────────────────────────────────────
-- Drawn by rain/TransitionFx.qml in the matrix-rain process:
--   workspace switch: every window on the new workspace decodes out of glyphs
--   window open:      the window materializes out of a block of glyphs
--   window close:     the window de-rezzes, glyph columns dropping away
local function tfx(args) matrix_fx_send("trans " .. args) end
local function geo(w)
  local ok, g = pcall(function() return string.format("%d %d %d %d", w.at.x, w.at.y, w.size.x, w.size.y) end)
  return ok and g or nil
end

local last_ws = nil
hl.on("workspace.active", function(ws)
  local ok, id = pcall(function() return ws.id end)
  if not ok or type(id) ~= "number" or id <= 0 or id == last_ws then return end
  local first = last_ws == nil
  last_ws = id
  if first then return end
  -- every window on the new workspace decodes out of glyphs, same as an open
  for _, x in ipairs(hl.get_windows()) do
    local okx, wid = pcall(function() return x.workspace.id end)
    if okx and wid == id then
      local g = geo(x)
      if g then tfx("open " .. g) end
    end
  end
end)

hl.on("window.open", function(w)
  if not w then return end
  local ok, addr = pcall(function() return w.address end)
  if not ok then return end
  -- wait a beat so the window has its final size, then materialize it
  hl.timer(function()
    for _, x in ipairs(hl.get_windows()) do
      if x.address == addr then
        local g = geo(x)
        if g then tfx("open " .. g) end
        return
      end
    end
  end, { timeout = 10, type = "oneshot" })
end)

-- fullscreen / floating toggles: rescan the window at its new geometry once
-- it has settled
local function rescan(w)
  local g = geo(w)
  if g then tfx("toggle " .. g) end
end
hl.on("window.fullscreen", function(w) if w then rescan(w) end end)
on_float_toggle = rescan

hl.on("window.close", function(w)
  if not w then return end
  local g = geo(w)
  if g then tfx("close " .. g) end
end)
