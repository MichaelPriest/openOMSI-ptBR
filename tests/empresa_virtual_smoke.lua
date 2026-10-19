-- Smoke/regression tests for Empresa Virtual (Lua 5.4).
-- Run from the repository root: lua5.4 tests/empresa_virtual_smoke.lua
local callbacks, timers, logs, hotkeys, toasts = {}, {}, {}, {}, {}
local data = {}
local duty_start_calls = 0

omsi = {
  version = "test-runtime",
  data = data,
  info = function()
    return { map = "Mapa de teste", line = "136", tour = "3", trip = "3", next_stop = "Terminal", delay = 0, speed = 0, clock = 36000, passengers = 0 }
  end,
  on = function(name, fn)
    callbacks[name] = callbacks[name] or {}
    table.insert(callbacks[name], fn)
  end,
  every = function(seconds, fn)
    table.insert(timers, { seconds = seconds, fn = fn })
    return #timers
  end,
  log = function(...)
    table.insert(logs, table.concat({ ... }, " "))
  end,
  message = function() end,
  save = function() end,
  plugin = {
    settings = function(schema)
      local result = {}
      for _, item in ipairs(schema) do result[item.key] = item.default end
      return result
    end,
  },
  ui = {
    set = function() return true end,
    toast = function(message) table.insert(toasts, tostring(message)); return true end,
  },
  duty = {
    get = function() return { line = "136", tour = "3", trip = "3", delay = 0 } end,
    start = function() duty_start_calls = duty_start_calls + 1; return true end,
  },
  bus = { state = function() return { speed = 0 } end },
  map = { speed_limit = function() return 50 end },
  input = {
    hotkey = function(chord, fn) hotkeys[chord] = fn; return #hotkeys end,
    bindings = function() return {} end,
  },
}

local root = "plugins/empresa_virtual/"
package.path = root .. "?.lua;" .. package.path
dofile(root .. "main.lua")

local function emit(name, ...)
  for _, fn in ipairs(callbacks[name] or {}) do fn(...) end
end
local function tick(seconds)
  for _ = 1, seconds do
    for _, timer in ipairs(timers) do
      if timer.seconds == 1 then timer.fn() end
    end
  end
end
local function count_events(kind)
  local events = data.empresa_virtual_events or {}
  local n = 0
  for _, event in ipairs(events) do if event.k == kind then n = n + 1 end end
  return n
end

assert(callbacks.start and #callbacks.start > 0, "plugin must register start event")
-- Misordered user settings must not grant a senior rank before the driver threshold.
emit("setting", "promotion_xp_senior", 0)
emit("setting", "promotion_xp_driver", 100)
emit("setting", "promotion_xp_instructor", 200)
emit("start")
assert(data.empresa_virtual_career ~= nil, "career must persist locally at startup")
assert(data.empresa_virtual_career.rank == "Aprendiz",
  "promotion thresholds must be monotonic even when settings are misconfigured")

-- The host must not start a second duty when one is already active.
emit("ui_click", "empresa_virtual_dashboard", "ev_dispatch")
assert(duty_start_calls == 0, "dispatch must refuse when the driver already has an active duty")

-- The old and new duty event names must not create two career records.
emit("duty", "136", "3")
emit("duty_start", "136", "3")
assert(count_events("duty") == 1, "equivalent duty events must be deduplicated")
emit("duty", nil, nil)
assert(count_events("duty_end") == 1, "giving up a duty must be recorded as an end, not a new duty")
emit("duty", nil, nil)
assert(count_events("duty_end") == 1, "duplicate no-duty events must not create repeated end records")

-- A stop change and stop_depart can report the same completion.
emit("next_stop", "Ponto seguinte", "Terminal")
emit("stop_depart", "Terminal", "terminal-id", 1, 0)
assert((data.empresa_virtual_career.completed_stops or 0) == 1,
  "equivalent stop events must award only one completion")
assert((data.empresa_virtual_career.xp or 0) == 10,
  "one completed stop must award configured XP once")

-- Different stops must not be suppressed just because they occur close together.
emit("stop_depart", "Ponto seguinte", "stop-2", 2, 0)
assert((data.empresa_virtual_career.completed_stops or 0) == 2,
  "a different stop must count even inside the dedupe window")
assert((data.empresa_virtual_career.xp or 0) == 20,
  "a different stop must award XP even inside the dedupe window")

-- Repeating the same stop event in the dedupe window must not award twice.
emit("stop_depart", "Ponto seguinte", "stop-2", 2, 0)
assert((data.empresa_virtual_career.completed_stops or 0) == 2,
  "the same stop repeated inside the dedupe window must be ignored")
assert((data.empresa_virtual_career.xp or 0) == 20,
  "duplicate stop event must not award XP twice")

-- A later stop on the same duty must still count after the dedupe window.
tick(3)
emit("stop_depart", "Próxima parada", "stop-3", 3, 0)
assert((data.empresa_virtual_career.completed_stops or 0) == 3,
  "a later stop must be counted")
assert((data.empresa_virtual_career.xp or 0) == 30,
  "XP must increase exactly once for the later stop")

-- Changing promotion rules must refresh the saved rank without waiting for another stop.
emit("setting", "promotion_xp_senior", 500)
emit("setting", "promotion_xp_instructor", 1500)
emit("setting", "promotion_xp_driver", 20)
assert(data.empresa_virtual_career.rank == "Motorista",
  "rank must be recalculated immediately when promotion thresholds change")

-- DriverOps is integrated into the Lua plugin and binds the legacy F9/F10 actions.
assert(type(hotkeys.F9) == "function", "F9 must expose the full DriverOps operational report")
assert(type(hotkeys.F10) == "function", "F10 must expose the quick DriverOps status")
hotkeys.F9()
local full_report = table.concat(toasts, "\n")
assert(full_report:find("DRIVEROPS", 1, true), "full DriverOps report must identify itself")
assert(full_report:find("Próxima parada: Terminal", 1, true), "DriverOps must use the live next-stop field")
assert(full_report:find("Limite 50 km/h", 1, true), "DriverOps must report the live map speed limit")
assert(full_report:find("Passageiros 0", 1, true), "DriverOps must report live passenger count")
hotkeys.F10()
assert(toasts[#toasts]:find("DriverOps", 1, true) and toasts[#toasts]:find("Terminal", 1, true),
  "quick DriverOps status must include live stop information")

-- Public plugin API fallback: menu and actions must work through documented key events.
local toast_count_before_menu = #toasts
emit("key", "F2", true)
assert(#toasts == toast_count_before_menu + 1 and toasts[#toasts]:find("EMPRESA VIRTUAL", 1, true),
  "F2 must open a usable keyboard menu when custom UI click support is absent")
emit("key", "1", true)
assert(toasts[#toasts]:find("CARREIRA", 1, true) and toasts[#toasts]:find("XP:", 1, true),
  "menu option 1 must show the real career summary")
emit("key", "F2", true)
local toast_start_driverops = #toasts
emit("key", "4", true)
local driverops_menu_report = table.concat(toasts, "\\n", toast_start_driverops + 1)
assert(driverops_menu_report:find("DRIVEROPS", 1, true),
  "menu option 4 must launch DriverOps without requiring an unsupported clickable panel")

-- Required UI/log fallbacks should not report multiplayer in offline mode.
local compat = require("compat")
assert(compat.mode == "solo-offline", "missing LAN APIs must remain offline")
local found_startup_log = false
for _, line in ipairs(logs) do
  if line:find("modo=solo%-offline") then found_startup_log = true end
end
assert(found_startup_log, "startup diagnostics must include detected mode")

print("Empresa Virtual smoke tests: OK")
