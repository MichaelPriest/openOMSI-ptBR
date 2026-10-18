-- Empresa Virtual: adaptador de compatibilidade para APIs de openOMSI.
-- Recursos ausentes nunca são simulados como se tivessem funcionado.
local M = { api = "empresa-virtual-compat/1.2", capabilities = {} }

local function has(path)
  local v = omsi
  for p in path:gmatch("[^.]+") do
    if type(v) ~= "table" then return false end
    v = v[p]
  end
  return type(v) == "function"
end

local function table_at(path)
  local v = omsi
  for p in path:gmatch("[^.]+") do
    if type(v) ~= "table" then return false end
    v = v[p]
  end
  return type(v) == "table"
end

local function install_fallbacks()
  local lan_complete = has("lan.active") and has("lan.me") and has("lan.players")
    and has("lan.send") and has("json.encode") and has("json.decode")
  -- Persistência: usa o armazenamento oficial quando disponível; caso contrário,
  -- utiliza omsi.data, que é a API documentada nas versões básicas.
  if type(omsi.storage) ~= "table" then omsi.storage = {} end
  if type(omsi.storage.get) ~= "function" then
    omsi.storage.get = function(key)
      if type(omsi.data) ~= "table" then return nil end
      return omsi.data["empresa_virtual_" .. tostring(key)]
    end
  end
  if type(omsi.storage.set) ~= "function" then
    omsi.storage.set = function(key, value)
      if type(omsi.data) ~= "table" then return false, "omsi.data indisponível" end
      omsi.data["empresa_virtual_" .. tostring(key)] = value
      return true
    end
  end

  -- Compatibilidade de leitura de escala e velocidade.
  if type(omsi.duty) ~= "table" then omsi.duty = {} end
  if type(omsi.duty.get) ~= "function" then
    omsi.duty.get = function()
      local info = type(omsi.info) == "function" and (omsi.info() or {}) or {}
      return {
        line = info.line, tour = info.tour, trip = info.trip,
        next_stop = info.next_stop, delay = info.delay,
      }
    end
  end
  if type(omsi.bus) ~= "table" then omsi.bus = {} end
  if type(omsi.bus.state) ~= "function" then
    omsi.bus.state = function()
      local info = type(omsi.info) == "function" and (omsi.info() or {}) or {}
      return { speed = tonumber(info.speed) or (type(omsi.speed) == "function" and tonumber(omsi.speed())) or 0 }
    end
  end
  if type(omsi.map) ~= "table" then omsi.map = {} end
  if type(omsi.map.speed_limit) ~= "function" then
    omsi.map.speed_limit = function() return nil end
  end

  -- Solo/offline real: não inventa jogadores, host nem envio bem-sucedido.
  if type(omsi.lan) ~= "table" then omsi.lan = {} end
  if type(omsi.lan.active) ~= "function" then omsi.lan.active = function() return false end end
  if type(omsi.lan.me) ~= "function" then omsi.lan.me = function() return 0, "Motorista local", false end end
  if type(omsi.lan.players) ~= "function" then omsi.lan.players = function() return {} end end
  if type(omsi.lan.send) ~= "function" then
    omsi.lan.send = function() return false, "Esta versão não oferece transporte multiplayer para plugins" end
  end
  -- Multiplayer só fica ativo quando sessão, envio e JSON existem juntos.
  -- Uma API parcial não pode fazer o plugin entrar por engano em caminhos de rede.
  if not lan_complete then
    omsi.lan.active = function() return false end
    omsi.lan.me = function() return 0, "Motorista local", false end
    omsi.lan.players = function() return {} end
    omsi.lan.send = function() return false, "Multiplayer indisponível nesta versão" end
  end

  -- Se a versão não tem painel de configurações do plugin, manter os valores
  -- padrão permite carreira local sem interromper o carregamento.
  if type(omsi.plugin) ~= "table" then omsi.plugin = {} end
  if type(omsi.plugin.settings) ~= "function" then
    omsi.plugin.settings = function(schema)
      local result = {}
      for _, item in ipairs(schema or {}) do
        if type(item) == "table" and type(item.key) == "string" then
          result[item.key] = item.default
        end
      end
      return result
    end
  end

  if type(omsi.ui) ~= "table" then omsi.ui = {} end
  if type(omsi.ui.toast) ~= "function" then
    omsi.ui.toast = function(message, opts)
      if type(omsi.message) == "function" then
        local seconds = type(opts) == "table" and tonumber(opts.seconds) or 5
        omsi.message(tostring(message), seconds or 5)
        return true
      end
      return false, "mensagens na tela indisponíveis"
    end
  end
  if type(omsi.ui.set) ~= "function" then
    omsi.ui.set = function() return false, "painéis personalizados não são suportados nesta versão" end
  end
  if type(omsi.game) ~= "table" then omsi.game = {} end
  if type(omsi.game.notify) ~= "function" then
    omsi.game.notify = function(message)
      if type(omsi.message) == "function" then omsi.message(tostring(message), 5); return true end
      if type(omsi.log) == "function" then omsi.log(tostring(message)); return true end
      return false, "notificação indisponível"
    end
  end
end

function M.detect()
  local c = {
    plugin_settings = has("plugin.settings"),
    storage_get_set = has("storage.get") and has("storage.set"),
    native_saved_data = type(omsi.data) == "table",
    lan_session = has("lan.active") and has("lan.me") and has("lan.players"),
    lan_send = has("lan.send"),
    json_codec = has("json.encode") and has("json.decode"),
    duty_get = has("duty.get"), duty_start = has("duty.start"),
    info = has("info"), bus_state = has("bus.state"),
    map_speed_limit = has("map.speed_limit"),
    ui_panel = has("ui.set"), ui_toast = has("ui.toast"),
    input_events = has("on"), key_events = true,
  }
  M.capabilities = c
  M.multiplayer = c.lan_session and c.lan_send and c.json_codec
  M.mode = M.multiplayer and "multiplayer-capable" or "solo-offline"
  -- A leitura de info e o registro de eventos são o mínimo para iniciar.
  M.can_run = c.info and c.input_events
  return M
end

function M.report()
  local names = {}
  for k, v in pairs(M.capabilities or {}) do
    names[#names + 1] = k .. "=" .. (v and "sim" or "não")
  end
  table.sort(names)
  return "Empresa Virtual compat " .. M.api ..
    "; modo=" .. tostring(M.mode or "desconhecido") ..
    "; jogo=" .. tostring((omsi and omsi.version) or "versão não informada") ..
    "; capacidades: " .. table.concat(names, ", ")
end

function M.startup()
  local r = M.detect()
  install_fallbacks()
  -- Relatórios mostram APIs nativas da build, não os fallbacks locais instalados.
  M.capabilities = r.capabilities
  M.multiplayer = r.multiplayer
  M.mode = r.mode
  M.can_run = r.can_run
  if r.can_run then
    if type(omsi.log) == "function" then
      omsi.log(M.report())
      if not r.multiplayer then
        omsi.log("Empresa Virtual: modo local/offline; multiplayer não foi detectado e não será simulado.")
      end
      if not r.capabilities.plugin_settings then
        omsi.log("Empresa Virtual: esta versão não oferece painel nativo de configurações; usando padrões locais.")
      end
      if not r.capabilities.ui_panel then
        omsi.log("Empresa Virtual: painel visual não disponível nesta versão; comandos visuais usam mensagens quando possível.")
      end
    end
    return true
  end
  local msg = "Empresa Virtual: APIs mínimas ausentes (info/eventos). " .. M.report()
  if type(omsi.log) == "function" then omsi.log(msg) end
  if type(omsi.message) == "function" then pcall(omsi.message, msg, 12) end
  return false
end

return M
