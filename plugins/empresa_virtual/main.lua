-- Empresa Virtual openOMSI: agente de operações por regras configuráveis.
-- Camada de compatibilidade: falha de forma explícita se faltarem APIs essenciais.
local compat = require("compat")
if not compat.startup() then return end

-- API de referência: openOMSI v0.3.37 docs/PLUGINS.md e docs/plugin-api.json.
local settings = omsi.plugin.settings({
  { key = "enabled", type = "bool", label = "Ativar Empresa Virtual", default = true },
  { key = "company_name", type = "text", label = "Nome da empresa", default = "Viação Virtual" },
  { key = "driver_role", type = "text", label = "Cargo do motorista neste computador", default = "Motorista" },
  { key = "show_status", type = "bool", label = "Mostrar status ao pressionar F7", default = true },
  { key = "save_events", type = "bool", label = "Registrar eventos e viagens", default = true },
  { key = "sync_multiplayer", type = "bool", label = "Sincronizar eventos pelo multiplayer", default = true },
  { key = "warn_speed", type = "bool", label = "Alertar excesso de velocidade", default = true },
  { key = "speed_tolerance", type = "number", label = "Tolerância acima do limite (km/h)", default = 5, min = 0, max = 30, step = 1 },
  { key = "speed_repeat_seconds", type = "number", label = "Intervalo entre alertas de velocidade (s)", default = 20, min = 5, max = 180, step = 5 },
  { key = "warn_delay", type = "bool", label = "Alertar atrasos", default = true },
  { key = "delay_warn_seconds", type = "number", label = "Atraso para emitir alerta (s)", default = 180, min = 0, max = 3600, step = 30 },
  { key = "delay_critical_seconds", type = "number", label = "Atraso crítico (s)", default = 600, min = 0, max = 7200, step = 60 },
  { key = "warn_crash", type = "bool", label = "Registrar e alertar colisões", default = true },
  { key = "crash_penalty", type = "number", label = "Pontos descontados por colisão", default = 15, min = 0, max = 100, step = 1 },
  { key = "punctuality_weight", type = "number", label = "Peso da pontualidade (0 a 100)", default = 40, min = 0, max = 100, step = 5 },
  { key = "safety_weight", type = "number", label = "Peso da condução segura (0 a 100)", default = 40, min = 0, max = 100, step = 5 },
  { key = "service_weight", type = "number", label = "Peso do serviço (0 a 100)", default = 20, min = 0, max = 100, step = 5 },
  { key = "minimum_score", type = "number", label = "Pontuação mínima recomendada", default = 70, min = 0, max = 100, step = 5 },
  { key = "xp_per_stop", type = "number", label = "Experiência por parada concluída", default = 10, min = 0, max = 100, step = 5 },
  { key = "promotion_xp_driver", type = "number", label = "XP para Motorista", default = 100, min = 0, max = 10000, step = 25 },
  { key = "promotion_xp_senior", type = "number", label = "XP para Motorista Sênior", default = 500, min = 0, max = 25000, step = 50 },
  { key = "promotion_xp_instructor", type = "number", label = "XP para Instrutor", default = 1500, min = 0, max = 50000, step = 100 },
  { key = "speed_score_penalty", type = "number", label = "Pontos perdidos por alerta de velocidade", default = 2, min = 0, max = 25, step = 1 },
  { key = "punctual_stop_reward", type = "number", label = "Pontos por parada pontual", default = 1, min = 0, max = 5, step = 1 },
  { key = "dispatch_enabled", type = "bool", label = "Permitir despacho de viagens pelo host", default = true },
  { key = "dispatch_line", type = "text", label = "Linha padrão para despacho", default = "136" },
  { key = "dispatch_tour", type = "text", label = "Viagem/tabela padrão para despacho", default = "3" },
  { key = "dispatch_minimum_score", type = "number", label = "Nota mínima para receber despacho", default = 50, min = 0, max = 100, step = 5 },
  { key = "auto_accept_dispatch", type = "bool", label = "Aceitar despacho do host automaticamente", default = true },
  { key = "host_authoritative", type = "bool", label = "Host é autoridade dos registros sincronizados", default = true },
  { key = "hotkey_roster", type = "text", label = "Atalho do painel de motoristas", default = "Ctrl+Alt+KeyM" },
  { key = "hotkey_dispatch", type = "text", label = "Atalho para despacho", default = "Ctrl+Alt+KeyD" },
  { key = "hotkey_status", type = "text", label = "Atalho para status", default = "Ctrl+Alt+KeyP" },
  { key = "hotkey_save", type = "text", label = "Atalho para salvar registros", default = "Ctrl+Alt+KeyS" },
}, "Agente de Operações — Empresa Virtual")

local enabled = settings.enabled ~= false
local function cfg(key, fallback)
  local value = settings[key]
  if value == nil then return fallback end
  return value
end

local company_name = tostring(cfg("company_name", "Viação Virtual"))
local events = omsi.storage.get("events") or {}
local career = omsi.storage.get("career") or { xp = 0, score = 100, rank = "Aprendiz", completed_stops = 0 }
career.xp = tonumber(career.xp) or 0
career.score = math.max(0, math.min(100, tonumber(career.score) or 100))
career.completed_stops = tonumber(career.completed_stops) or 0
local seq = tonumber(omsi.storage.get("event_seq")) or 0
local pending_events = omsi.storage.get("pending_events") or {}
local company_roster = omsi.storage.get("company_roster") or {}
-- Mantém IDs recentes separados do log visível, que é limitado a 300 eventos.
local seen_event_order = omsi.storage.get("seen_event_order") or {}
local seen_event_set = {}
for _, event_id in ipairs(seen_event_order) do
  if type(event_id) == "string" then seen_event_set[event_id] = true end
end
for _, event in ipairs(events) do
  if type(event.i) == "string" and not seen_event_set[event.i] then
    seen_event_order[#seen_event_order + 1] = event.i
    seen_event_set[event.i] = true
  end
end
while #seen_event_order > 1000 do
  local expired = table.remove(seen_event_order, 1)
  seen_event_set[expired] = nil
end
-- Idade em segundos locais desde a última atualização de perfil recebida.
-- Intencionalmente volátil: não transforma estado antigo persistido em presença atual.
local profile_age = {}
local roster_sync_queue = {}
-- Evita enfileirar várias cópias do mesmo snapshot enquanto ele ainda é enviado.
local roster_sync_active = {}
local roster_request_elapsed = 0
local pending_dispatches = omsi.storage.get("pending_dispatches") or {}
local dispatch_seq = tonumber(omsi.storage.get("dispatch_seq")) or 0
local driver_role = tostring(cfg("driver_role", "Motorista"))
local last_speed_warning = -100000
local last_delay_level = 0
local is_host = false
local my_id = 0
local roster_visible = false
local render_roster
local render_dashboard
local configure_hotkeys
local hotkey_ids = {}
local native_hotkeys = false

local function persist()
  while #events > 300 do table.remove(events, 1) end
  omsi.storage.set("events", events)
  omsi.storage.set("event_seq", seq)
  omsi.storage.set("pending_events", pending_events)
  omsi.storage.set("seen_event_order", seen_event_order)
  omsi.storage.set("company_roster", company_roster)
  omsi.storage.set("pending_dispatches", pending_dispatches)
  omsi.storage.set("dispatch_seq", dispatch_seq)
end

local function send_pending_event(event)
  if not (cfg("sync_multiplayer", true) and omsi.lan.active()) then return false end
  local destination = is_host and 0 or 1
  local ok, result = pcall(omsi.lan.send, destination, omsi.json.encode(event))
  return ok and result == true
end

local function queue_event(event)
  if is_host or not (cfg("sync_multiplayer", true) and omsi.lan.active()) then return end
  pending_events[#pending_events + 1] = event
  persist()
  send_pending_event(event)
end

local function remember_event_id(event_id)
  if type(event_id) ~= "string" or event_id == "" or seen_event_set[event_id] then return end
  seen_event_set[event_id] = true
  seen_event_order[#seen_event_order + 1] = event_id
  while #seen_event_order > 1000 do
    local expired = table.remove(seen_event_order, 1)
    seen_event_set[expired] = nil
  end
end

local function acknowledge_event(event_id)
  for i = #pending_events, 1, -1 do
    if pending_events[i].i == event_id then
      table.remove(pending_events, i)
    end
  end
  persist()
end

local toast

local function save_career()
  omsi.storage.set("career", career)
end

local allowed_roles = {
  ["Aprendiz"] = true,
  ["Motorista"] = true,
  ["Motorista Sênior"] = true,
  ["Instrutor"] = true,
  ["Despachante"] = true,
  ["Supervisor"] = true,
  ["Administrador"] = true,
}

local function normalized_role(value)
  value = tostring(value or "Motorista")
  if allowed_roles[value] then return value end
  return "Motorista"
end

driver_role = normalized_role(driver_role)

local function player_name_for_id(id)
  if tonumber(id) == 1 then
    local _, name = omsi.lan.me()
    return tostring(name or "Host")
  end
  local players = omsi.lan.players() or {}
  for _, player in ipairs(players) do
    if tonumber(player.id) == tonumber(id) then
      return tostring(player.name or ("Jogador " .. tostring(id)))
    end
  end
  return nil
end

local function queue_roster_snapshot(destination)
  if not is_host or not omsi.lan.active() then return end
  local target_key = tostring(destination)
  -- Coalesce pedidos repetidos enquanto o snapshot deste cliente está na fila.
  if roster_sync_active[target_key] then return end
  local first_queued = #roster_sync_queue + 1
  -- Enfileira uma cópia compacta por perfil; o envio é limitado abaixo para
  -- não disparar um burst de mensagens ao entrar na sessão.
  for name, profile in pairs(company_roster) do
    local safe_name = tostring(name or ""):gsub("|", ""):sub(1, 24)
    if safe_name ~= "" then
      local payload = omsi.json.encode({ v = 1, k = "roster", n = safe_name, r = normalized_role(profile.role), l = tostring(profile.line or ""):sub(1, 12), t = tostring(profile.tour or ""):sub(1, 12), a = profile.active == true and 1 or 0 })
      if #payload <= 120 and not payload:find("|", 1, true) then
        roster_sync_queue[#roster_sync_queue + 1] = { to = destination, payload = payload }
      end
    end
  end
  if #roster_sync_queue >= first_queued then
    roster_sync_active[target_key] = true
    roster_sync_queue[#roster_sync_queue].last_for_target = target_key
  end
end

local function send_profile()
  if not (omsi.lan.active() and cfg("sync_multiplayer", true) == true) then return end
  local duty = omsi.duty.get() or {}
  local line = tostring(duty.line or ""):gsub("|", ""):sub(1, 12)
  local tour = tostring(duty.tour or duty.trip or ""):gsub("|", ""):sub(1, 12)
  local active = (duty.line ~= nil or duty.tour ~= nil or duty.trip ~= nil) and 1 or 0
  if is_host then
    local _, name = omsi.lan.me()
    name = tostring(name or "Host")
    local profile = company_roster[name] or {}
    profile.role, profile.line, profile.tour, profile.active = driver_role, line, tour, active == 1
    profile_age[name] = 0
    profile.xp, profile.score = career.xp, career.score
    company_roster[name] = profile
    persist()
    local payload = omsi.json.encode({ v = 1, k = "roster", n = name:sub(1, 24), r = driver_role, l = line, t = tour, a = active })
    if #payload <= 120 and not payload:find("|", 1, true) then pcall(omsi.lan.send, 0, payload) end
  else
    local payload = omsi.json.encode({ v = 1, k = "profile", r = driver_role, l = line, t = tour, a = active })
    if #payload <= 120 and not payload:find("|", 1, true) then pcall(omsi.lan.send, 1, payload) end
  end
end

local function adjust_score(delta)
  career.score = math.max(0, math.min(100, career.score + delta))
  save_career()
end

local function update_rank()
  local xp = career.xp
  local rank = "Aprendiz"
  if xp >= (tonumber(cfg("promotion_xp_driver", 100)) or 100) then rank = "Motorista" end
  if xp >= (tonumber(cfg("promotion_xp_senior", 500)) or 500) then rank = "Motorista Sênior" end
  if xp >= (tonumber(cfg("promotion_xp_instructor", 1500)) or 1500) then rank = "Instrutor" end
  if career.rank ~= rank then
    career.rank = rank
    toast("Promoção de carreira: " .. rank .. " (" .. math.floor(xp) .. " XP)", 7)
  end
  save_career()
end

local function record(kind, fields)
  if cfg("save_events", true) ~= true then return end
  local info = omsi.info() or {}
  local duty = omsi.duty.get() or {}
  local event = {
    v = 1, k = kind, p = my_id,
    l = tostring(fields.line or duty.line or info.line or ""):sub(1, 12),
    t = tostring(fields.tour or duty.tour or info.tour or ""):sub(1, 12),
    n = tostring(fields.stop or ""):sub(1, 18),
    d = math.floor(tonumber(fields.delay or info.delay) or 0),
    tm = math.floor(tonumber(info.clock) or 0),
    i = tostring(my_id) .. ":" .. tostring(seq + 1),
  }
  seq = seq + 1
  event.q = seq
  events[#events + 1] = event
  persist()

  if cfg("sync_multiplayer", true) and omsi.lan.active() then
    local payload = omsi.json.encode(event)
    if #payload <= 120 and not payload:find("|", 1, true) then
      if is_host then
        local sent, result = pcall(omsi.lan.send, 0, payload)
        if not sent or result ~= true then
          omsi.log("Empresa Virtual: falha ao divulgar evento " .. tostring(event.i))
        end
      else
        queue_event(event)
      end
    end
  end
end

toast = function(message, seconds)
  pcall(function()
    omsi.ui.toast(tostring(message), {
      title = company_name,
      icon = "directions_bus",
      seconds = seconds or 5,
    })
  end)
end

local function snapshot()
  local info = omsi.info() or {}
  local duty = omsi.duty.get() or {}
  local bus = omsi.bus.state() or {}
  local passengers = info.passengers
  local me, name, host = omsi.lan.me()
  return {
    player = tostring(name or "Motorista"),
    player_id = me,
    host = host == true,
    map = tostring(info.map or ""),
    line = tostring(duty.line or info.line or "—"),
    tour = tostring(duty.tour or info.tour or "—"),
    trip = tostring(duty.trip or info.trip or "—"),
    next_stop = tostring(info.next_stop or "—"),
    delay = tonumber(duty.delay or info.delay) or 0,
    speed = tonumber(bus.speed or info.speed) or 0,
    passengers = tonumber(passengers) or 0,
    speed_limit = tonumber(omsi.map.speed_limit()) or 0,
    clock = tonumber(info.clock) or 0,
  }
end

render_roster = function()
  if not (omsi.ui and omsi.ui.set) then return end
  local map_info = omsi.info() or {}
  local children = {
    { type = "row", children = {
      { type = "icon", name = "groups", color = "#60A5FA", size = 20 },
      { type = "text", text = "EMPRESA VIRTUAL", size = 15, weight = "bold", grow = true },
      { type = "badge", text = is_host and "HOST" or "CLIENTE" },
    } },
    { type = "text", text = company_name .. " • " .. tostring(map_info.map or "Mapa não identificado"), size = 11, color = "#9CA3AF" },
    { type = "divider" },
  }
  local own = snapshot()
  children[#children + 1] = { type = "row", children = {
    { type = "text", text = tostring(own.player) .. " (você)", weight = "bold", grow = true },
    { type = "badge", text = string.format("%.0f km/h", own.speed) },
  } }
  children[#children + 1] = { type = "text", text = "Cargo: " .. driver_role .. " • Linha " .. own.line .. " • Viagem " .. own.tour .. " • Nota " .. tostring(math.floor(career.score)), size = 11, color = "#D1D5DB" }

  local players = {}
  if omsi.lan.active() then players = omsi.lan.players() or {} end
  table.sort(players, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
  children[#children + 1] = { type = "divider" }
  children[#children + 1] = { type = "text", text = "MOTORISTAS NA SESSÃO (" .. tostring(#players + 1) .. ")", size = 10, color = "#9CA3AF", weight = "bold" }
  for _, p in ipairs(players) do
    local name = tostring(p.name or ("Jogador " .. tostring(p.id or "?"))):sub(1, 28)
    local line = tostring(p.line or "—")
    local tour = tostring(p.tour or "—")
    local speed = tonumber(p.speed) or 0
    local profile = company_roster[name] or {}
    local role = normalized_role(profile.role)
    local age = profile_age[name]
    local status
    if age == nil or age > 25 then
      status = "SEM ATUALIZAÇÃO"
    elseif profile.active == true then
      status = "EM SERVIÇO"
    else
      status = "DISPONÍVEL"
    end
    children[#children + 1] = { type = "row", children = {
      { type = "text", text = name .. " · " .. role, grow = true },
      { type = "badge", text = status },
      { type = "text", text = line .. "/" .. tour, color = "#9CA3AF" },
      { type = "badge", text = string.format("%.0f", speed) },
    } }
  end
  if #players == 0 then
    children[#children + 1] = { type = "text", text = "Nenhum outro motorista conectado", size = 12, color = "#9CA3AF" }
  end
  children[#children + 1] = { type = "text", text = "Atalhos configuráveis nas opções da Empresa Virtual.", size = 10, color = "#9CA3AF" }
  children[#children + 1] = { type = "row", children = {
    { type = "button", id = "ev_roster_status", text = "Atualizar" },
    { type = "button", id = "ev_roster_hide", text = "Fechar painel" },
  } }

  local ok, why = omsi.ui.set("empresa_virtual_roster", {
    anchor = "top_right", x = 18, y = 390, width = 360, padding = 14, gap = 7,
    background = "#111827F2", radius = 14, accent = "#3B82F6",
    visible = roster_visible, draggable = true, children = children,
  })
  if not ok and why then omsi.log("Empresa Virtual: painel não atualizado: " .. tostring(why)) end
end

local function evaluate_rules()
  if not enabled then return end
  local s = snapshot()
  local now = s.clock
  local delay_level = 0

  -- Regras observacionais: alertam e registam, mas não controlam o autocarro.
  if cfg("warn_speed", true) then
    local limit = s.speed_limit
    local tolerance = math.max(0, tonumber(cfg("speed_tolerance", 5)) or 5)
    local interval = math.max(5, tonumber(cfg("speed_repeat_seconds", 20)) or 20)
    if limit > 0 and s.speed > limit + tolerance and now - last_speed_warning >= interval then
      last_speed_warning = now
      toast(string.format("Excesso de velocidade: %.0f km/h (limite %.0f)", s.speed, limit), 6)
      local weight = math.max(0, tonumber(cfg("safety_weight", 40)) or 40) / 40
      adjust_score(-(tonumber(cfg("speed_score_penalty", 2)) or 2) * weight)
      record("speed", { line = s.line, tour = s.tour, delay = s.delay })
    end
  end

  if cfg("warn_delay", true) then
    local warn = math.max(0, tonumber(cfg("delay_warn_seconds", 180)) or 180)
    local critical = math.max(warn, tonumber(cfg("delay_critical_seconds", 600)) or 600)
    if s.delay >= critical then delay_level = 2
    elseif s.delay >= warn then delay_level = 1 end
    if delay_level > last_delay_level then
      if delay_level == 2 then
        toast(string.format("Atraso crítico de %d s. Avalie a situação da linha.", math.floor(s.delay)), 8)
      elseif delay_level == 1 then
        toast(string.format("Atenção: atraso de %d s.", math.floor(s.delay)), 6)
      end
    end
  end
  last_delay_level = delay_level
end

omsi.on("setting", function(key, value)
  settings[key] = value
  if key == "hotkey_roster" or key == "hotkey_dispatch" or key == "hotkey_status" or key == "hotkey_save" then
    if configure_hotkeys then configure_hotkeys() end
    if render_dashboard then render_dashboard() end
  end
  if key == "enabled" then enabled = value == true end
  if key == "company_name" then company_name = tostring(value or "Viação Virtual") end
  if key == "driver_role" then
    driver_role = normalized_role(value)
    settings.driver_role = driver_role
    send_profile()
    if roster_visible then render_roster() end
  end
end)

omsi.on("start", function()
  my_id, _, is_host = omsi.lan.me()
  is_host = is_host == true
  update_rank()
  local _, session_name = omsi.lan.me()
  local own_name = tostring(session_name or "Motorista")
  company_roster[own_name] = company_roster[own_name] or { role = driver_role, xp = career.xp, score = career.score }
  company_roster[own_name].role = driver_role
  company_roster[own_name].xp = career.xp
  company_roster[own_name].score = career.score
  persist()
  send_profile()
  if not is_host and omsi.lan.active() and cfg("sync_multiplayer", true) == true then
    pcall(omsi.lan.send, 1, omsi.json.encode({ v = 1, k = "roster_request" }))
  end
  configure_hotkeys()
  render_roster()
  render_dashboard()
  if type(omsi.plugin.show_settings) == "function" then
    omsi.log("Empresa Virtual: configurações disponíveis no painel nativo; atalho/painel principal disponíveis.")
  end
  omsi.game.notify(company_name .. " carregada. Abra o painel Empresa Virtual para acessar a operação.", "info", 6)
  omsi.log(company_name .. " iniciada; host=" .. tostring(is_host))
end)

omsi.every(1, function()
  if is_host and omsi.lan.active() and #roster_sync_queue > 0 then
    -- No máximo cinco mensagens por segundo, abaixo do limite documentado da API.
    for _ = 1, math.min(5, #roster_sync_queue) do
      local item = table.remove(roster_sync_queue, 1)
      local ok, result = pcall(omsi.lan.send, item.to, item.payload)
      if not ok or result ~= true then
        omsi.log("Empresa Virtual: falha ao sincronizar perfil do cadastro")
      end
      if item.last_for_target then
        roster_sync_active[item.last_for_target] = nil
      end
    end
  end
end)

omsi.every(5, function()
  for name, age in pairs(profile_age) do profile_age[name] = (tonumber(age) or 0) + 5 end
  if roster_visible then render_roster() end
  render_dashboard()
  if not is_host or not omsi.lan.active() then return end
  for dispatch_id, pending in pairs(pending_dispatches) do
    pending.wait_seconds = (tonumber(pending.wait_seconds) or 0) + 5
    local received = (tonumber(pending.accepted) or 0) + (tonumber(pending.refused) or 0)
    if received >= (tonumber(pending.expected) or 0) then
      pending_dispatches[dispatch_id] = nil
      persist()
    elseif pending.wait_seconds >= 60 then
      local missing = math.max(0, (tonumber(pending.expected) or 0) - received)
      toast("Despacho " .. tostring(pending.line) .. "/" .. tostring(pending.tour) .. ": tempo esgotado; " .. tostring(pending.accepted or 0) .. " aceito(s), " .. tostring(pending.refused or 0) .. " recusado(s), " .. tostring(missing) .. " sem resposta.", 9)
      pending_dispatches[dispatch_id] = nil
      persist()
    end
  end
end)

local function dispatch_default_duty()
  if (omsi.lan.active() and not is_host) or cfg("dispatch_enabled", true) ~= true then
    toast("Somente o host pode despachar viagens na sessão multiplayer.", 5)
    return
  end
  local line = tostring(cfg("dispatch_line", "136") or ""):gsub("|", ""):sub(1, 20)
  local tour = tostring(cfg("dispatch_tour", "3") or ""):gsub("|", ""):sub(1, 20)
  if line == "" or tour == "" then
    toast("Configure uma linha e uma viagem válidas nas opções da Empresa Virtual.", 6)
    return
  end
  if career.score < (tonumber(cfg("dispatch_minimum_score", 50)) or 50) then
    toast("Nota abaixo do mínimo para despacho. Nota atual: " .. math.floor(career.score), 6)
    return
  end

  -- Confirma primeiro a escala local do host. Não distribui uma ordem se
  -- o host não conseguiu iniciar a própria viagem.
  local called, start_result, start_reason = pcall(omsi.duty.start, line, tour)
  if not called or start_result == false then
    toast("Não foi possível iniciar a escala do host: " .. tostring(start_reason or start_result), 7)
    return
  end
  toast("Escala do host iniciada: linha " .. line .. ", viagem " .. tour, 6)

  if omsi.lan.active() then
    dispatch_seq = dispatch_seq + 1
    local info = omsi.info() or {}
    local dispatch_id = tostring(math.floor(tonumber(info.clock) or 0)) .. "-" .. tostring(dispatch_seq)
    local players = omsi.lan.players() or {}
    if #players == 0 then
      toast("Nenhum outro motorista conectado; a escala ficou apenas no host.", 6)
      return
    end
    pending_dispatches[dispatch_id] = { line = line, tour = tour, expected = #players, accepted = 0, refused = 0, created = tonumber(info.clock) or 0, wait_seconds = 0, results = {} }
    persist()
    local command = { v = 1, k = "dispatch", d = dispatch_id, l = line, t = tour }
    local payload = omsi.json.encode(command)
    if #payload > 120 or payload:find("|", 1, true) then
      pending_dispatches[dispatch_id] = nil
      persist()
      toast("Escala iniciada no host, mas o comando excedeu o limite multiplayer.", 7)
      return
    end
    local sent, send_result, send_reason = pcall(omsi.lan.send, 0, payload)
    if not sent or send_result ~= true then
      pending_dispatches[dispatch_id] = nil
      persist()
      toast("Escala iniciada no host, mas o despacho não foi enviado: " .. tostring(send_reason or send_result), 7)
      return
    end
    toast("Despacho enviado para " .. tostring(#players) .. " motorista(s). Aguardando confirmações.", 7)
  end
end

local function show_status()
  local st = snapshot()
  toast(string.format("%s | %s | %d XP | Nota %d | Linha %s | Viagem %s | %.0f km/h | atraso %ds",
    st.player, career.rank, career.xp, career.score, st.line, st.trip, st.speed, math.floor(st.delay)), 8)
  if career.score < (tonumber(cfg("minimum_score", 70)) or 70) then
    toast("Nota abaixo do mínimo recomendado (" .. tostring(cfg("minimum_score", 70)) .. "). Revise segurança e pontualidade.", 6)
  end
end

local function save_records()
  persist()
  save_career()
  if type(omsi.save) == "function" then omsi.save() end
  if type(omsi.game.notify) == "function" then
    omsi.game.notify("Registros locais salvos.", "info", 4)
  else
    toast("Registros locais salvos.", 4)
  end
end

render_dashboard = function()
  if type(omsi.ui) ~= "table" or type(omsi.ui.set) ~= "function" then return end
  local st = snapshot()
  local mode = (omsi.lan.active() and "MULTIPLAYER" or "SOLO / OFFLINE")
  local panel = {
    anchor = "top_right", x = 18, y = 72, width = 330, padding = 12, gap = 7,
    background = "#111827F2", radius = 14, accent = "#3B82F6",
    visible = enabled, draggable = true, grab = true,
    children = {
      { type = "row", children = {
        { type = "icon", name = "directions_bus", color = "#60A5FA", size = 20 },
        { type = "text", text = "EMPRESA VIRTUAL", size = 15, weight = "bold", grow = true },
        { type = "badge", text = mode },
      } },
      { type = "text", text = company_name .. " • " .. tostring(st.map ~= "" and st.map or "Mapa não identificado"), size = 11, color = "#9CA3AF" },
      { type = "row", children = {
        { type = "text", text = st.player, weight = "bold", grow = true },
        { type = "badge", text = driver_role },
      } },
      { type = "row", children = {
        { type = "text", text = "XP " .. tostring(career.xp), grow = true },
        { type = "badge", text = "Nota " .. tostring(math.floor(career.score)) },
        { type = "badge", text = career.rank },
      } },
      { type = "text", text = "Linha " .. st.line .. " • Viagem " .. st.tour .. " • Próxima: " .. st.next_stop, size = 11 },
      { type = "text", text = string.format("%.0f km/h • atraso %ds", st.speed, math.floor(st.delay)), size = 11, color = st.delay > 180 and "#FCA5A5" or "#D1D5DB" },
      { type = "divider" },
      { type = "row", children = {
        { type = "button", id = "ev_open_roster", text = "Motoristas" },
        { type = "button", id = "ev_dispatch", text = "Despachar" },
      } },
      { type = "row", children = {
        { type = "button", id = "ev_status", text = "Status" },
        { type = "button", id = "ev_save", text = "Salvar" },
        { type = "button", id = "ev_settings", text = "Configurar" },
      } },
      { type = "text", text = "Atalhos: " .. tostring(cfg("hotkey_roster", "Ctrl+Alt+KeyM")) .. " • " .. tostring(cfg("hotkey_dispatch", "Ctrl+Alt+KeyD")), size = 9, color = "#9CA3AF" },
    },
  }
  local ok, why = omsi.ui.set("empresa_virtual_dashboard", panel)
  if not ok and why then omsi.log("Empresa Virtual: painel principal não atualizado: " .. tostring(why)) end
end

configure_hotkeys = function()
  if type(omsi.cancel) == "function" then
    for _, id in ipairs(hotkey_ids) do pcall(omsi.cancel, id) end
  end
  hotkey_ids = {}
  native_hotkeys = type(omsi.input) == "table" and type(omsi.input.hotkey) == "function"
  if not native_hotkeys then
    omsi.log("Empresa Virtual: atalhos com modificadores indisponíveis; nenhum atalho antigo será assumido como livre.")
    return
  end

  local bindings = {}
  if type(omsi.input.bindings) == "function" then
    local ok, result = pcall(omsi.input.bindings)
    if ok and type(result) == "table" then bindings = result end
  end
  local actions = {
    { key = "hotkey_roster", fallback = "Ctrl+Alt+KeyM", label = "motoristas", run = function() roster_visible = not roster_visible; render_roster(); render_dashboard() end },
    { key = "hotkey_dispatch", fallback = "Ctrl+Alt+KeyD", label = "despacho", run = dispatch_default_duty },
    { key = "hotkey_status", fallback = "Ctrl+Alt+KeyP", label = "status", run = show_status },
    { key = "hotkey_save", fallback = "Ctrl+Alt+KeyS", label = "salvar", run = save_records },
  }
  local used = {}
  for _, action in ipairs(actions) do
    local chord = tostring(cfg(action.key, action.fallback) or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if chord == "" then
      omsi.log("Empresa Virtual: atalho vazio; ação " .. action.label .. " não vinculada.")
    elseif used[chord] then
      toast("Atalho duplicado (" .. chord .. "): " .. action.label .. " não foi vinculado.", 7)
    else
      local conflict
      for _, binding in ipairs(bindings) do
        if type(binding) == "table" and tostring(binding.key or "") == chord then
          conflict = tostring(binding.action or "comando do simulador")
          break
        end
      end
      if conflict then
        toast("Conflito de atalho: " .. chord .. " já está associado a " .. conflict .. ". Altere nas configurações.", 8)
        omsi.log("Empresa Virtual: atalho " .. chord .. " conflita com " .. conflict)
      else
        local ok, id = pcall(omsi.input.hotkey, chord, function()
          if enabled and not (type(omsi.ui.typing) == "function" and omsi.ui.typing()) then action.run() end
        end)
        if ok and type(id) == "number" then
          hotkey_ids[#hotkey_ids + 1] = id
          used[chord] = true
        else
          toast("Não foi possível registrar o atalho " .. chord .. " (" .. action.label .. ").", 6)
          omsi.log("Empresa Virtual: falha ao registrar atalho " .. chord .. ": " .. tostring(id))
        end
      end
    end
  end
  omsi.log("Empresa Virtual: atalhos configuráveis registrados=" .. tostring(#hotkey_ids))
end

omsi.on("ui_click", function(panel, element)
  if panel == "empresa_virtual_dashboard" then
    if element == "ev_open_roster" then
      roster_visible = not roster_visible
      render_roster()
      render_dashboard()
    elseif element == "ev_dispatch" then
      dispatch_default_duty()
    elseif element == "ev_status" then
      show_status()
    elseif element == "ev_save" then
      save_records()
    elseif element == "ev_settings" then
      if type(omsi.plugin.show_settings) == "function" then
        omsi.plugin.show_settings(true)
      else
        toast("Esta versão não oferece painel nativo de configurações.", 6)
      end
    end
  elseif panel == "empresa_virtual_roster" then
    if element == "ev_roster_hide" then roster_visible = false; render_roster()
    elseif element == "ev_roster_status" then show_status(); render_roster() end
  end
end)

-- Compatibilidade: em builds antigas sem hotkey chords, não tomamos teclas F*
-- conhecidas como livres. As ações ficam disponíveis pelo painel clicável.
omsi.on("key", function(key, down)
  if not down or not enabled or native_hotkeys then return end
  if key == "F10" and type(omsi.ui.focus) == "function" then
    omsi.ui.focus(not omsi.ui.focused())
  end
end)

omsi.on("duty_start", function(line, tour)
  last_delay_level = 0
  record("duty", { line = line, tour = tour })
  toast("Escala iniciada: linha " .. tostring(line or "—") .. ", viagem " .. tostring(tour or "—"), 5)
end)

-- API documentada nas builds base (docs/PLUGINS.md): evento "duty".
-- Mantemos "duty_start" para builds que disponibilizam esse evento específico.
omsi.on("duty", function(line, tour)
  if not enabled then return end
  last_delay_level = 0
  record("duty", { line = line, tour = tour })
  toast("Escala iniciada: linha " .. tostring(line or "—") .. ", viagem " .. tostring(tour or "—"), 5)
end)

-- Compatibilidade com o evento oficial "next_stop" nas builds base.
-- Uma mudança de parada representa conclusão da parada anterior; não inferimos
-- colisões nem eventos que a API não expõe.
omsi.on("next_stop", function(new_stop, old_stop)
  if not enabled or new_stop == nil or new_stop == old_stop or old_stop == nil then return end
  career.completed_stops = career.completed_stops + 1
  career.xp = career.xp + math.max(0, tonumber(cfg("xp_per_stop", 10)) or 10)
  local info = omsi.info() or {}
  local actual_delay = tonumber(info.delay) or 0
  local warn = math.max(0, tonumber(cfg("delay_warn_seconds", 180)) or 180)
  local critical = math.max(warn, tonumber(cfg("delay_critical_seconds", 600)) or 600)
  local punctuality_weight = math.max(0, tonumber(cfg("punctuality_weight", 40)) or 40) / 40
  if actual_delay >= critical then
    adjust_score(-5 * punctuality_weight)
  elseif actual_delay >= warn then
    adjust_score(-2 * punctuality_weight)
  else
    adjust_score(math.max(0, tonumber(cfg("punctual_stop_reward", 1)) or 1) * punctuality_weight)
  end
  update_rank()
  save_career()
  record("depart", { stop = old_stop, delay = actual_delay, source = "next_stop" })
end)

omsi.on("stop_arrive", function(name, id, number, delay)
  record("arrive", { stop = id or name, delay = delay })
end)

omsi.on("stop_depart", function(name, id, number, delay)
  local actual_delay = tonumber(delay) or 0
  career.completed_stops = career.completed_stops + 1
  career.xp = career.xp + math.max(0, tonumber(cfg("xp_per_stop", 10)) or 10)

  local warn = math.max(0, tonumber(cfg("delay_warn_seconds", 180)) or 180)
  local critical = math.max(warn, tonumber(cfg("delay_critical_seconds", 600)) or 600)
  local punctuality_weight = math.max(0, tonumber(cfg("punctuality_weight", 40)) or 40) / 40
  if actual_delay >= critical then
    adjust_score(-5 * punctuality_weight)
  elseif actual_delay >= warn then
    adjust_score(-2 * punctuality_weight)
  else
    adjust_score(math.max(0, tonumber(cfg("punctual_stop_reward", 1)) or 1) * punctuality_weight)
  end

  update_rank()
  save_career()
  record("depart", { stop = id or name, delay = delay })
end)

omsi.on("crash", function(energy, speed)
  if cfg("warn_crash", true) then
    local points = math.max(0, tonumber(cfg("crash_penalty", 15)) or 15)
    local weight = math.max(0, tonumber(cfg("safety_weight", 40)) or 40) / 40
    adjust_score(-points * weight)
    toast(string.format("Colisão registada. Penalidade: %d pontos. Nota atual: %d.", math.floor(points), math.floor(career.score)), 7)
    record("crash", { stop = tostring(math.floor(tonumber(energy) or 0)) .. "kJ", delay = speed })
  end
end)

omsi.on("lan_message", function(from, raw)
  if not enabled or cfg("sync_multiplayer", true) ~= true then return end
  if type(raw) ~= "string" or #raw > 120 then return end
  local ok, e = pcall(omsi.json.decode, raw)
  if not ok or type(e) ~= "table" or e.v ~= 1 or type(e.k) ~= "string" then return end

  if e.k == "roster_request" then
    if not is_host or tonumber(from) == 1 then return end
    queue_roster_snapshot(tonumber(from))
    return
  end

  if e.k == "profile" then
    if not is_host or tonumber(from) == 1 then return end
    local name = player_name_for_id(from)
    if not name then return end
    local role = normalized_role(e.r)
    local profile = company_roster[name] or {}
    profile.role = role
    profile.line = type(e.l) == "string" and e.l:sub(1, 12) or ""
    profile.tour = type(e.t) == "string" and e.t:sub(1, 12) or ""
    profile.active = tonumber(e.a) == 1
    local session_info = omsi.info() or {}
    profile.last_seen = tonumber(session_info.clock) or 0
    profile_age[name] = 0
    profile.xp = tonumber(profile.xp) or 0
    profile.score = tonumber(profile.score) or 100
    company_roster[name] = profile
    persist()
    local roster_payload = omsi.json.encode({ v = 1, k = "roster", n = name:sub(1, 24), r = role, l = profile.line, t = profile.tour, a = profile.active and 1 or 0 })
    if #roster_payload <= 120 and not roster_payload:find("|", 1, true) then
      local broadcast_ok, broadcast_result = pcall(omsi.lan.send, 0, roster_payload)
      if not broadcast_ok or broadcast_result ~= true then
        omsi.log("Empresa Virtual: não foi possível distribuir perfil de " .. name)
      end
    end
    if roster_visible then render_roster() end
    return
  end

  if e.k == "roster" then
    if is_host or tonumber(from) ~= 1 or type(e.n) ~= "string" or e.n == "" then return end
    local name = e.n:gsub("|", ""):sub(1, 24)
    local profile = company_roster[name] or {}
    profile.role = normalized_role(e.r)
    profile.line = type(e.l) == "string" and e.l:sub(1, 12) or ""
    profile.tour = type(e.t) == "string" and e.t:sub(1, 12) or ""
    profile.active = tonumber(e.a) == 1
    profile_age[name] = 0
    company_roster[name] = profile
    persist()
    if roster_visible then render_roster() end
    return
  end

  if e.k == "ack" then
    if not is_host and tonumber(from) == 1 and type(e.i) == "string" then
      acknowledge_event(e.i)
    end
    return
  end

  if e.k == "dispatch" then
    -- Apenas clientes podem aceitar comandos de despacho; o host nunca aceita comandos de clientes.
    if is_host or tonumber(from) ~= 1 then return end
    local function reply_dispatch(accepted, reason)
      if type(e.d) ~= "string" or #e.d > 20 then return end
      local result = omsi.json.encode({ v = 1, k = "dispatch_result", d = e.d, a = accepted and 1 or 0, x = reason or "ERRO" })
      if #result <= 120 and not result:find("|", 1, true) then pcall(omsi.lan.send, 1, result) end
    end
    if cfg("auto_accept_dispatch", true) ~= true then
      toast("Despacho recebido, mas a aceitação automática está desativada.", 6)
      reply_dispatch(false, "MANUAL")
      return
    end
    local line = type(e.l) == "string" and e.l:gsub("|", ""):sub(1, 20) or ""
    local tour = type(e.t) == "string" and e.t:gsub("|", ""):sub(1, 20) or ""
    if line == "" or tour == "" then reply_dispatch(false, "INVALIDO"); return end
    local min_score = tonumber(cfg("dispatch_minimum_score", 50)) or 50
    if career.score < min_score then
      toast("Despacho recusado: sua nota está abaixo do mínimo da empresa.", 7)
      reply_dispatch(false, "NOTA")
      return
    end
    local current = omsi.duty.get() or {}
    if current.line ~= nil or current.tour ~= nil or current.trip ~= nil then
      toast("Despacho recusado: você já está em uma escala. Termine-a antes de aceitar outra.", 8)
      reply_dispatch(false, "OCUPADO")
      return
    end
    local called, start_result, why = pcall(omsi.duty.start, line, tour)
    local accepted = called and start_result ~= false
    local reason = accepted and "OK" or "ERRO"
    if accepted then
      toast("Despacho recebido: linha " .. line .. ", viagem " .. tour, 7)
    else
      toast("Falha ao iniciar despacho: " .. tostring(why or start_result), 7)
    end
    reply_dispatch(accepted, reason)
    return
  end

  if e.k == "dispatch_result" then
    if not is_host or tonumber(from) == 1 or type(e.d) ~= "string" then return end
    local pending = pending_dispatches[e.d]
    if not pending then return end
    local name = player_name_for_id(from) or ("Jogador " .. tostring(from))
    local result_key = tostring(from)
    pending.results = pending.results or {}
    if pending.results[result_key] then return end
    local accepted = tonumber(e.a) == 1
    pending.results[result_key] = { name = name, accepted = accepted }
    if accepted then pending.accepted = (tonumber(pending.accepted) or 0) + 1
    else pending.refused = (tonumber(pending.refused) or 0) + 1 end
    persist()
    toast(name .. (accepted and " aceitou" or " recusou/falhou ao iniciar") .. " a linha " .. tostring(pending.line) .. "/" .. tostring(pending.tour) .. ". Confirmações: " .. tostring((pending.accepted or 0) + (pending.refused or 0)) .. "/" .. tostring(pending.expected or 0), 7)
    if (pending.accepted or 0) + (pending.refused or 0) >= (pending.expected or 0) then
      toast("Confirmações do despacho concluídas: " .. tostring(pending.accepted or 0) .. " aceito(s), " .. tostring(pending.refused or 0) .. " recusado(s)/falha(s).", 8)
      pending_dispatches[e.d] = nil
      persist()
    end
    return
  end

  if not ({ duty = true, arrive = true, depart = true, crash = true, speed = true })[e.k] then return end
  if type(e.i) ~= "string" or #e.i > 24 then return end

  if is_host and cfg("host_authoritative", true) then
    -- O host valida o remetente, elimina reenvios e atribui a sequência oficial.
    if tonumber(from) == 1 then return end
    if seen_event_set[e.i] then
      pcall(omsi.lan.send, tonumber(from), omsi.json.encode({ v = 1, k = "ack", i = e.i }))
      return
    end
    remember_event_id(e.i)
    seq = seq + 1
    e.q = seq
    e.p = tonumber(from) or e.p
    events[#events + 1] = e
    persist()
    local ack_ok, ack_result = pcall(omsi.lan.send, tonumber(from), omsi.json.encode({ v = 1, k = "ack", i = e.i }))
    if not ack_ok or ack_result ~= true then
      omsi.log("Empresa Virtual: confirmação não enviada para o evento " .. tostring(e.i))
    end
    local payload = omsi.json.encode(e)
    if #payload <= 120 and not payload:find("|", 1, true) then
      local sent, result = pcall(omsi.lan.send, 0, payload)
      if not sent or result ~= true then omsi.log("Empresa Virtual: evento não divulgado " .. tostring(e.i)) end
    end
  else
    if tonumber(from) ~= 1 or not tonumber(e.q) then return end
    local last = tonumber(omsi.storage.get("last_host_seq")) or 0

    -- Aceita eventos fora de ordem, pois uma sequência mais alta não prova
    -- que todos os eventos anteriores chegaram. A deduplicação é pelo ID.
    local already_local = false
    for _, previous in ipairs(events) do
      if previous.i == e.i then
        previous.q = e.q
        previous.p = e.p
        already_local = true
        break
      end
    end
    if not already_local and not seen_event_set[e.i] then
      events[#events + 1] = e
      remember_event_id(e.i)
    end
    if e.q > last then last = e.q end
    omsi.storage.set("last_host_seq", last)
    persist()
  end
end)

omsi.every(2, evaluate_rules)

-- Reenvia eventos ainda sem confirmação do host, com limite de uma tentativa por ciclo.
-- A fila fica persistida para sobreviver a recargas do plugin e desconexões temporárias.
omsi.every(10, function()
  if not enabled then return end
  send_profile()
  if not is_host and omsi.lan.active() and cfg("sync_multiplayer", true) == true then
    roster_request_elapsed = roster_request_elapsed + 10
    if roster_request_elapsed >= 30 then
      roster_request_elapsed = 0
      -- Reconsulta o cadastro a cada 30 segundos para recuperar perfis perdidos
      -- sem solicitar snapshots completos a cada heartbeat.
      pcall(omsi.lan.send, 1, omsi.json.encode({ v = 1, k = "roster_request" }))
    end
  else
    roster_request_elapsed = 0
  end
end)

omsi.every(5, function()
  if is_host or not enabled or cfg("sync_multiplayer", true) ~= true or not omsi.lan.active() then return end
  if #pending_events == 0 then return end
  -- Rotaciona a fila: um evento sem ACK não bloqueia os eventos seguintes.
  local event = table.remove(pending_events, 1)
  -- Reinsere e persiste antes de enviar, evitando perder um ACK que chegue
  -- imediatamente enquanto o evento ainda não voltou para a fila.
  pending_events[#pending_events + 1] = event
  persist()
  local sent = send_pending_event(event)
  if not sent then
    omsi.log("Empresa Virtual: aguardando confirmação do evento " .. tostring(event.i))
  end
end)
