-- Empresa Virtual: deteccao de capacidades sem presumir compatibilidade por versao.
-- Este modulo nao inventa aliases para APIs nao documentadas. Ele identifica o que
-- a instancia realmente oferece e fornece diagnostico para instalacoes diferentes.
local M = { api = "empresa-virtual-compat/1", capabilities = {} }

local function has(path)
  local value = omsi
  for part in path:gmatch("[^.]+") do
    if type(value) ~= "table" then return false end
    value = value[part]
  end
  return type(value) == "function"
end

local function table_at(path)
  local value = omsi
  for part in path:gmatch("[^.]+") do
    if type(value) ~= "table" then return false end
    value = value[part]
  end
  return type(value) == "table"
end

function M.detect()
  local c = {
    plugin_settings = has("plugin.settings"),
    storage_get_set = has("storage.get") and has("storage.set"),
    lan_session = has("lan.active") and has("lan.me") and has("lan.players"),
    lan_send = has("lan.send"),
    json_codec = has("json.encode") and has("json.decode"),
    duty_get = has("duty.get"),
    info = has("info"),
    bus_state = has("bus.state"),
    map_speed_limit = has("map.speed_limit"),
    ui_toast = has("ui.toast"),
    game_notify = has("game.notify"),
    event_api = has("on"),
    settings_event = table_at("plugin"),
  }
  M.capabilities = c
  local missing = {}
  for _, name in ipairs({"plugin_settings", "storage_get_set", "lan_session", "lan_send",
      "json_codec", "duty_get", "info", "ui_toast"}) do
    if not c[name] then missing[#missing + 1] = name end
  end
  M.missing_required = missing
  M.multiplayer = c.lan_session and c.lan_send and c.json_codec
  M.career_storage = c.storage_get_set
  M.can_run = #missing == 0
  return M
end

function M.report()
  local c = M.capabilities or {}
  local names = {}
  for key, value in pairs(c) do
    names[#names + 1] = key .. "=" .. (value and "yes" or "no")
  end
  table.sort(names)
  return "Empresa Virtual compat " .. M.api .. "; jogo=" ..
    tostring((omsi and omsi.version) or "versao nao informada") ..
    "; capacidades: " .. table.concat(names, ", ")
end

function M.startup()
  local result = M.detect()
  if result.can_run then
    if omsi and omsi.log then omsi.log(M.report()) end
    return true
  end
  local message = "Empresa Virtual: API incompativel ou incompleta. " ..
    "Nao iniciou para evitar falhas. Faltam: " .. table.concat(result.missing_required, ", ") ..
    ". " .. M.report()
  if omsi and omsi.log then omsi.log(message) end
  if omsi and omsi.ui and type(omsi.ui.toast) == "function" then
    pcall(omsi.ui.toast, message, 12)
  elseif omsi and omsi.message then
    pcall(omsi.message, message, 12)
  end
  return false
end

return M
