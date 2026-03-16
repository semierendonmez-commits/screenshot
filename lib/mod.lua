-- screenshot
-- v3.0.0 @semi
--
-- screen capture mod
-- K1+K2+K3: manual capture
-- auto-capture via params

local mod = require 'core/mods'

local state = {
  k1 = false, k2 = false,
  flash = 0,
  count = 0,
  auto_clock = nil,
  auto_secs = 0,
  dir = _path.data .. "screenshots/",
}

local INTERVAL_OPTS = {"OFF", "10s", "20s", "30s", "1min", "5min"}
local INTERVAL_SECS = {0, 10, 20, 30, 60, 300}

local function ensure_dir()
  os.execute("mkdir -p " .. state.dir)
end

local function gen_filename()
  local ts = os.date("%Y%m%d_%H%M%S")
  local sname = "norns"
  pcall(function()
    if norns.state.name then sname = norns.state.name:gsub("[^%w_-]", "") end
  end)
  state.count = state.count + 1
  return string.format("%s%s_%s_%03d.png", state.dir, ts, sname, state.count)
end

local function capture()
  ensure_dir()
  local path = gen_filename()
  -- norns screen capture API
  if _norns.screen_export_png then
    _norns.screen_export_png(path)
    print("screenshot: " .. path)
    state.flash = 3
  end
end

local function stop_auto()
  if state.auto_clock then
    pcall(function() clock.cancel(state.auto_clock) end)
    state.auto_clock = nil
  end
end

local function start_auto(secs)
  stop_auto()
  if secs <= 0 then return end
  state.auto_secs = secs
  state.auto_clock = clock.run(function()
    while true do
      clock.sleep(secs)
      local menu_active = _menu and _menu.mode
      if not menu_active then capture() end
    end
  end)
  print("screenshot: auto every " .. secs .. "s")
end

-- ============ PARAMS ============

local function add_params()
  params:add_separator("SCREENSHOT")

  params:add_trigger("ss_take", "> take screenshot")
  params:set_action("ss_take", function() capture() end)

  params:add_option("ss_auto", "auto capture", INTERVAL_OPTS, 1)
  params:set_action("ss_auto", function(v)
    local secs = INTERVAL_SECS[v] or 0
    if secs > 0 then start_auto(secs) else stop_auto() end
  end)
end

-- ============ HOOKS ============

mod.hook.register("script_post_init", "screenshot", function()
  add_params()

  -- wrap key for K1+K2+K3
  local script_key = key
  key = function(n, z)
    if n == 1 then state.k1 = (z == 1) end
    if n == 2 then state.k2 = (z == 1) end
    if state.k1 and state.k2 and n == 3 and z == 1 then
      capture()
      return
    end
    if script_key then script_key(n, z) end
  end

  -- wrap redraw for flash
  local script_redraw = redraw
  redraw = function()
    if script_redraw then script_redraw() end
    if state.flash > 0 then
      screen.level(math.floor(state.flash * 4))
      screen.rect(0, 0, 128, 64); screen.fill()
      screen.update()
      state.flash = state.flash - 1
    end
  end
end)

mod.hook.register("script_post_cleanup", "screenshot", function()
  state.k1 = false; state.k2 = false; state.flash = 0
  stop_auto()
end)

-- ============ MOD MENU ============

local m = {}

m.key = function(n, z)
  if n == 2 and z == 1 then mod.menu.exit()
  elseif n == 3 and z == 1 then capture(); mod.menu.redraw()
  end
end

m.enc = function(n, d)
  if n == 3 then
    pcall(function() params:delta("ss_auto", d) end)
    mod.menu.redraw()
  end
end

m.redraw = function()
  screen.clear()
  screen.font_face(1); screen.font_size(8)
  screen.level(10); screen.move(64, 16); screen.text_center("screenshot")
  screen.level(5); screen.move(64, 28); screen.text_center("K1+K2+K3: capture")
  screen.move(64, 38); screen.text_center("saved: " .. state.count)
  screen.level(4); screen.move(64, 48)
  local atxt = state.auto_secs > 0 and ("auto: " .. state.auto_secs .. "s") or "auto: off"
  screen.text_center(atxt)
  screen.level(2); screen.move(64, 60); screen.text_center("K3:now  E3:auto")
  screen.update()
end

m.init = function() end
m.deinit = function() stop_auto() end
mod.menu.register(mod.this_name, m)
