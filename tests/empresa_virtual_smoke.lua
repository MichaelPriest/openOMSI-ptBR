-- Smoke/regression tests for Empresa Virtual (Lua 5.4).
-- Run from the repository root: lua5.4 tests/empresa_virtual_smoke.lua
local callbacks, timers, logs = {}, {}, {}
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
    toast = function() return true end,
  },
  duty = {
    get = function() return { line = "136", tour = "3", trip = "3", delay = 0 } end,
    start = function() duty_start_calls = duty_start_calls + 1; return true end,
  },
  bus = { state = function() return { speed = 0 } end },
  map = { speed_limit = function() return 50 end },
  input = {
    hotkey = function() return 1 end,
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
emit("start")
assert(data.empresa_virtual_career ~= nil, "career must persist locally at startup")

-- The host must not start a second duty when one is already active.
emit("ui_click", "empresa_virtual_dashboard", "ev_dispatch")
assert(duty_start_calls == 0, "dispatch must refuse when the driver already has an active duty")

-- The old and new duty event names must not create two career records.
emit("duty", "136", "3")
emit("duty_start", "136", "3")
assert(count_events("duty") == 1, "equivalent duty events must be deduplicated")

-- A stop change and stop_depart can report the same completion.
emit("next_stop", "Ponto seguinte", "Terminal")
emit("stop_depart", "Terminal", "terminal-id", 1, 0)
assert((data.empresa_virtual_career.completed_stops or 0) == 1,
  "equivalent stop events must award only one completion")
assert((data.empresa_virtual_career.xp or 0) == 10,
  "one completed stop must award configured XP once")

-- A later stop on the same duty must still count after the dedupe window.
tick(3)
emit("stop_depart", "Ponto seguinte", "stop-2", 2, 0)
assert((data.empresa_virtual_career.completed_stops or 0) == 2,
  "a later stop must be counted")
assert((data.empresa_virtual_career.xp or 0) == 20,
  "XP must increase exactly once for the later stop")

-- Required UI/log fallbacks should not report multiplayer in offline mode.
local compat = require("compat")
assert(compat.mode == "solo-offline", "missing LAN APIs must remain offline")
local found_startup_log = false
for _, line in ipairs(logs) do
  if line:find("modo=solo%-offline") then found_startup_log = true end
end
assert(found_startup_log, "startup diagnostics must include detected mode")

print("Empresa Virtual smoke tests: OK")
