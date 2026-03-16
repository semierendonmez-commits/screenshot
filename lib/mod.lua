-- screenshot
-- v1.0.0 @semi
--
-- capture norns screen as PNG
-- K1+K2+K3: take screenshot
--
-- files saved to dust/data/screenshots/

local mod = require 'core/mods'

local state = {
  k1 = false,
  k2 = false,
  k3 = false,
  flash = 0,
  count = 0,
  dir = _path.data .. "screenshots/",
}

-- ensure directory exists
local function ensure_dir()
  os.execute("mkdir -p " .. state.dir)
end

-- generate filename: YYYYMMDD_HHMMSS_scriptname_NNN.png
local function gen_filename()
  local ts = os.date("%Y%m%d_%H%M%S")
  local sname = "norns"
  if norns and norns.state and norns.state.name then
    sname = norns.state.name:gsub("[^%w_-]", "")
  end
  state.count = state.count + 1
  return string.format("%s%s_%s_%03d.png", state.dir, ts, sname, state.count)
end

-- take the screenshot
local function capture()
  ensure_dir()
  local path = gen_filename()
  -- _norns.screen_export_png exports current framebuffer
  if _norns and _norns.screen_export_png then
    _norns.screen_export_png(path)
    print("screenshot: saved " .. path)
    state.flash = 4  -- white flash frames
  else
    print("screenshot: export function not available")
  end
end

-- hook into key events to detect K1+K2+K3
local original_key = nil

mod.hook.register("script_post_init", "screenshot", function()
  -- wrap the script's key handler
  local script_key = key
  key = function(n, z)
    if n == 1 then state.k1 = (z == 1) end
    if n == 2 then state.k2 = (z == 1) end
    if n == 3 then state.k3 = (z == 1) end

    -- detect triple press: K1 held + K2 held + K3 pressed
    if state.k1 and state.k2 and n == 3 and z == 1 then
      capture()
      return  -- consume this key event
    end

    -- pass through to script
    if script_key then script_key(n, z) end
  end

  -- wrap redraw for flash effect
  local script_redraw = redraw
  redraw = function()
    if script_redraw then script_redraw() end
    if state.flash > 0 then
      screen.level(math.floor(state.flash * 3))
      screen.rect(0, 0, 128, 64)
      screen.fill()
      screen.update()
      state.flash = state.flash - 1
    end
  end
end)

mod.hook.register("script_post_cleanup", "screenshot", function()
  state.k1 = false
  state.k2 = false
  state.k3 = false
  state.flash = 0
end)

-- mod menu
local m = {}

m.key = function(n, z)
  if n == 2 and z == 1 then
    mod.menu.exit()
  elseif n == 3 and z == 1 then
    capture()
  end
end

m.enc = function(n, d) end

m.redraw = function()
  screen.clear()
  screen.level(10)
  screen.move(64, 20)
  screen.text_center("screenshot")
  screen.level(4)
  screen.move(64, 32)
  screen.text_center("K1+K2+K3 to capture")
  screen.move(64, 42)
  screen.text_center("saved: " .. state.count)
  screen.level(2)
  screen.move(64, 54)
  screen.text_center("K3: test capture")
  screen.update()
end

m.init = function() end
m.deinit = function() end

mod.menu.register(mod.this_name, m)
