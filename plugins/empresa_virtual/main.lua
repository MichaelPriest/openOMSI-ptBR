-- Empresa Virtual openOMSI
-- API pública: docs/PLUGINS.md da tag v0.3.37.
-- Protocolo multiplayer: mensagens JSON compactas <= 120 caracteres, sem "|".
local UDP_PORT = 47800
local panel_settings = omsi.plugin.settings({
  { key = "enabled", type = "bool", label = "Ativar Empresa Virtual", default = true },
  { key = "run_ai", type = "bool", label = "Ativar IA local neste host", default = false },
}, "Empresa Virtual")
local enabled = panel_settings.enabled ~= false
local run_ai = panel_settings.run_ai == true
local is_host = false
local my_id = 0
local seq = tonumber(omsi.storage.get("event_seq")) or 0
local events = omsi.storage.get("events") or {}
local last_ai_notice = ""

local function trim(s, n)
  s = tostring(s or "")
  if #s > n then return s:sub(1, n) end
  return s
end

local function save_events()
  while #events > 300 do table.remove(events, 1) end
  omsi.storage.set("events", events)
  omsi.storage.set("event_seq", seq)
end

local function append_event(e)
  events[#events + 1] = e
  save_events()
end

local function send_to_host(e)
  local payload = omsi.json.encode(e)
  if #payload > 120 or payload:find("|", 1, true) then
    omsi.log("Evento não sincronizado: mensagem ultrapassa o limite multiplayer.")
    return false
  end
  if is_host then
    seq = seq + 1
    e.q = seq
    append_event(e)
    omsi.lan.send(0, omsi.json.encode(e))
    return true
  end
  return omsi.lan.send(1, payload)
end

local function event_record(kind, fields)
  if not enabled or not omsi.lan.active() then return end
  local e = {
    v = 1,
    k = kind,
    p = my_id,
    l = trim(fields.line, 12),
    t = trim(fields.tour, 12),
    n = trim(fields.stop, 24),
    d = math.floor(tonumber(fields.delay) or 0),
  }
  send_to_host(e)
end

local function current_snapshot()
  local info = omsi.info() or {}
  local duty = omsi.duty.get() or {}
  local bus = omsi.bus.state() or {}
  local total = omsi.bus.passengers()
  local me, name, host = omsi.lan.me()
  return {
    kind = "state",
    player = trim(name, 32),
    player_id = me,
    map = trim(info.map, 48),
    line = trim(duty.line or info.line, 12),
    tour = trim(duty.tour or info.tour, 12),
    trip = tonumber(duty.trip or info.trip) or 0,
    stop = trim(type(duty.next_stop) == "table" and duty.next_stop.name or info.next_stop, 32),
    delay = math.floor(tonumber(duty.delay or info.delay) or 0),
    speed = math.floor(tonumber(bus.speed or info.speed) or 0),
    passengers = tonumber(total) or tonumber(info.passengers) or 0,
    host = host == true,
  }
end

local function check_ai_inbox()
  if not is_host or not enabled or not run_ai then return end
  local raw = omsi.plugin.read("agent-inbox.json")
  if not raw or raw == "" then return end
  local data = omsi.json.decode(raw)
  if type(data) ~= "table" or type(data.recommendation) ~= "string" then return end
  local rec = trim(data.recommendation, 180)
  if rec ~= "" and rec ~= last_ai_notice then
    last_ai_notice = rec
    omsi.ui.toast(rec, { title = "IA de Operações", icon = "psychology", seconds = 8 })
  end
end

omsi.on("setting", function(key, value)
  if key == "enabled" then enabled = value == true end
  if key == "run_ai" then run_ai = value == true end
end)

omsi.on("start", function()
  my_id, _, is_host = omsi.lan.me()
  is_host = is_host == true
  omsi.game.notify("Empresa Virtual carregada. F7: status, F6: salvar dados.", "info", 6)
  omsi.log("Empresa Virtual iniciada; host=" .. tostring(is_host) .. ", jogador=" .. tostring(my_id))
end)

omsi.on("key", function(key, down)
  if not down or not enabled then return end
  if key == "F7" then
    local s = current_snapshot()
    omsi.ui.toast(string.format("%s | Linha %s | Viagem %s | Atraso %s s",
      s.player, s.line, s.tour, s.delay), { title = "Empresa Virtual", icon = "directions_bus", seconds = 6 })
  elseif key == "F6" then
    save_events()
    omsi.storage.save()
    omsi.game.notify("Registros locais da Empresa Virtual salvos.", "info", 4)
  end
end)

omsi.on("duty_start", function(line, tour)
  event_record("duty", { line = line, tour = tour })
end)

omsi.on("stop_arrive", function(name, id, number, delay)
  local d = omsi.duty.get() or {}
  event_record("arrive", { line = d.line, tour = d.tour, stop = name, delay = delay })
end)

omsi.on("stop_depart", function(name, id, number, delay)
  local d = omsi.duty.get() or {}
  event_record("depart", { line = d.line, tour = d.tour, stop = name, delay = delay })
end)

omsi.on("crash", function(energy, speed)
  local d = omsi.duty.get() or {}
  event_record("crash", { line = d.line, tour = d.tour, stop = tostring(math.floor(tonumber(energy) or 0)) .. "kJ", delay = speed })
end)

omsi.on("lan_message", function(from, raw)
  if not enabled or type(raw) ~= "string" or #raw > 120 then return end
  local e = omsi.json.decode(raw)
  if type(e) ~= "table" or e.v ~= 1 or type(e.k) ~= "string" then return end
  if is_host then
    -- O host é o único que atribui sequência aos eventos oficiais.
    if tonumber(from) == 1 or not ({ duty = true, arrive = true, depart = true, crash = true })[e.k] then return end
    seq = seq + 1
    e.q = seq
    e.p = tonumber(from) or e.p
    append_event(e)
    local rebroadcast = omsi.json.encode(e)
    if #rebroadcast <= 120 and not rebroadcast:find("|", 1, true) then omsi.lan.send(0, rebroadcast) end
  else
    -- Só aceita eventos publicados pelo host (id 1).
    if tonumber(from) ~= 1 or not tonumber(e.q) then return end
    local current = tonumber(omsi.storage.get("last_host_seq")) or 0
    if e.q <= current then return end
    append_event(e)
    omsi.storage.set("last_host_seq", e.q)
  end
end)

omsi.every(5, function()
  if not enabled or not omsi.lan.active() then return end
  my_id, _, is_host = omsi.lan.me()
  is_host = is_host == true
  if is_host and run_ai then
    local s = current_snapshot()
    local payload = omsi.json.encode(s)
    if #payload <= 8192 then omsi.send(UDP_PORT, payload) end
  end
end)

omsi.every(10, check_ai_inbox)
