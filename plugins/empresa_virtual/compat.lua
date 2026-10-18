-- Deteccao por capacidades. Multiplayer e opcional: solo/offline nao exige API LAN.
local M = { api = "empresa-virtual-compat/1.1", capabilities = {} }
local function has(path)
  local v = omsi
  for p in path:gmatch("[^.]+") do if type(v) ~= "table" then return false end; v = v[p] end
  return type(v) == "function"
end
local function table_at(path)
  local v = omsi
  for p in path:gmatch("[^.]+") do if type(v) ~= "table" then return false end; v = v[p] end
  return type(v) == "table"
end
function M.detect()
  local c = {
    plugin_settings = has("plugin.settings"),
    storage_get_set = has("storage.get") and has("storage.set"),
    lan_session = has("lan.active") and has("lan.me") and has("lan.players"),
    lan_send = has("lan.send"),
    json_codec = has("json.encode") and has("json.decode"),
    duty_get = has("duty.get"), info = has("info"),
    bus_state = has("bus.state"), map_speed_limit = has("map.speed_limit"),
    ui_toast = has("ui.toast"), game_notify = has("game.notify"),
    event_api = has("on"), settings_event = table_at("plugin"),
  }
  M.capabilities = c
  local missing = {}
  for _, name in ipairs({"plugin_settings", "storage_get_set", "duty_get", "info"}) do
    if not c[name] then missing[#missing + 1] = name end
  end
  M.missing_required = missing
  M.multiplayer = c.lan_session and c.lan_send and c.json_codec
  M.career_storage = c.storage_get_set
  M.mode = M.multiplayer and "multiplayer-capable" or "solo-offline"
  M.can_run = #missing == 0
  return M
end
local function install_offline_lan()
  -- No-op realista: nunca simula jogadores nem confirma envio de mensagens.
  if type(omsi.lan) ~= "table" then omsi.lan = {} end
  if type(omsi.lan.active) ~= "function" then omsi.lan.active = function() return false end end
  if type(omsi.lan.me) ~= "function" then omsi.lan.me = function() return 0, "Solo", false end end
  if type(omsi.lan.players) ~= "function" then omsi.lan.players = function() return {} end end
  if type(omsi.lan.send) ~= "function" then omsi.lan.send = function() return false, "LAN indisponivel" end end
end
function M.report()
  local names = {}
  for k,v in pairs(M.capabilities or {}) do names[#names+1] = k .. "=" .. (v and "yes" or "no") end
  table.sort(names)
  return "Empresa Virtual compat " .. M.api .. "; modo=" .. tostring(M.mode or "unknown") ..
    "; jogo=" .. tostring((omsi and omsi.version) or "versao nao informada") ..
    "; capacidades: " .. table.concat(names, ", ")
end
function M.startup()
  local r = M.detect()
  if r.can_run then
    if not r.multiplayer then install_offline_lan() end
    if omsi and omsi.log then
      omsi.log(M.report())
      if not r.multiplayer then omsi.log("Empresa Virtual: carreira local habilitada; sincronizacao multiplayer indisponivel.") end
    end
    return true
  end
  local msg = "Empresa Virtual: APIs essenciais ausentes: " .. table.concat(r.missing_required, ", ") .. ". " .. M.report()
  if omsi and omsi.log then omsi.log(msg) end
  if omsi and omsi.ui and type(omsi.ui.toast) == "function" then pcall(omsi.ui.toast, msg, 12)
  elseif omsi and omsi.message then pcall(omsi.message, msg, 12) end
  return false
end
return M
