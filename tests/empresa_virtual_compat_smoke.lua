-- Compatibility regression tests for older/partial openOMSI Lua APIs.
-- Run from the repository root: lua5.4 tests/empresa_virtual_compat_smoke.lua

local root = "plugins/empresa_virtual/"
package.path = root .. "?.lua;" .. package.path

local function reset_runtime(runtime)
  _G.omsi = runtime
  package.loaded.compat = nil
  return require("compat")
end

-- Older build: only the documented core info/event/message/data APIs exist.
local old_logs, old_messages = {}, {}
local old = {
  version = "older-build",
  data = {},
  info = function()
    return { line = "A1", trip = "2", speed = 23.5, next_stop = "Centro" }
  end,
  on = function() end,
  log = function(message) old_logs[#old_logs + 1] = tostring(message) end,
  message = function(message) old_messages[#old_messages + 1] = tostring(message) end,
}
local compat = reset_runtime(old)
assert(compat.startup(), "older runtime with info/events must start in compatibility mode")
assert(compat.mode == "solo-offline", "older runtime must stay offline")
assert(not compat.capabilities.plugin_settings, "test must detect missing native settings")
assert(not compat.capabilities.ui_panel, "test must detect missing native panels")
assert(old.storage.set("probe", "saved"), "storage fallback must persist into native data")
assert(old.storage.get("probe") == "saved", "storage fallback must read the saved value")
local duty = old.duty.get()
assert(duty.line == "A1" and duty.next_stop == "Centro", "duty fallback must expose real info fields")
assert(old.bus.state().speed == 23.5, "bus fallback must preserve actual speed")
assert(old.map.speed_limit() == nil, "missing speed limit must remain unavailable, not fabricated")
assert(old.lan.active() == false, "missing LAN API must not report an active session")
assert(#old_logs > 0, "compatibility diagnostics must be logged")

-- Partial LAN API: an old build exposes some network functions but lacks JSON.
local partial = {
  version = "partial-lan-build",
  data = {},
  info = function() return { line = "B2", speed = 0 } end,
  on = function() end,
  log = function() end,
  lan = {
    active = function() return true end,
    me = function() return 7, "Test Driver", true end,
    players = function() return { { id = 7 } } end,
    send = function() return true end,
  },
}
compat = reset_runtime(partial)
assert(compat.startup(), "partial-LAN runtime should still start locally")
assert(compat.mode == "solo-offline", "partial LAN without JSON must not enable multiplayer")
assert(compat.multiplayer == false, "partial LAN must not be treated as multiplayer-capable")
assert(partial.lan.active() == false, "partial LAN must be safely disabled")
local ok, reason = partial.lan.send("event", {})
assert(ok == false and type(reason) == "string", "disabled LAN send must report failure")

-- A runtime lacking essential info/events must fail closed instead of crashing.
compat = reset_runtime({ version = "unsupported-build", log = function() end })
assert(not compat.startup(), "runtime without info/events must fail startup explicitly")

print("Empresa Virtual compatibility smoke tests: OK")
