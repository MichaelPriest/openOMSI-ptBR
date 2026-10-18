-- Empresa Virtual openOMSI: agente de operações por regras configuráveis.
-- API de referência: openOMSI v0.3.37 docs/PLUGINS.md e docs/plugin-api.json.
local settings = omsi.plugin.settings({
  { key = "enabled", type = "bool", label = "Ativar Empresa Virtual", default = true },
  { key = "company_name", type = "text", label = "Nome da empresa", default = "Viação Virtual" },
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
local last_speed_warning = -100000
local last_delay_level = 0
local is_host = false
local my_id = 0
local roster_visible = false

local function persist()
  while #events > 300 do table.remove(events, 1) end
  omsi.storage.set("events", events)
  omsi.storage.set("event_seq", seq)
end

local toast

local function save_career()
  omsi.storage.set("career", career)
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
        omsi.lan.send(0, payload)
      else
        omsi.lan.send(1, payload)
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

local function render_roster()
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
  children[#children + 1] = { type = "text", text = "Linha " .. own.line .. " • Viagem " .. own.tour .. " • Nota " .. tostring(math.floor(career.score)) .. " • " .. career.rank, size = 11, color = "#D1D5DB" }

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
    children[#children + 1] = { type = "row", children = {
      { type = "text", text = name, grow = true },
      { type = "text", text = line .. "/" .. tour, color = "#9CA3AF" },
      { type = "badge", text = string.format("%.0f", speed) },
    } }
  end
  if #players == 0 then
    children[#children + 1] = { type = "text", text = "Nenhum outro motorista conectado", size = 12, color = "#9CA3AF" }
  end
  children[#children + 1] = { type = "text", text = "F4: mostrar/ocultar • F5: despacho do host", size = 10, color = "#9CA3AF" }

  local ok, why = omsi.ui.set("empresa_virtual_roster", {
    anchor = "top_right", x = 18, y = 72, width = 360, padding = 14, gap = 7,
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
  if key == "enabled" then enabled = value == true end
  if key == "company_name" then company_name = tostring(value or "Viação Virtual") end
end)

omsi.on("start", function()
  my_id, _, is_host = omsi.lan.me()
  is_host = is_host == true
  update_rank()
  render_roster()
  omsi.game.notify(company_name .. " carregada. F4: motoristas; F5: despacho; F7: status.", "info", 6)
  omsi.log(company_name .. " iniciada; host=" .. tostring(is_host))
end)

omsi.every(5, function()
  if roster_visible then render_roster() end
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

  local command = { v = 1, k = "dispatch", l = line, t = tour }
  local payload = omsi.json.encode(command)
  if #payload > 120 or payload:find("|", 1, true) then
    toast("Despacho não enviado: dados excedem o limite multiplayer.", 6)
    return
  end

  -- Valida a disponibilidade do host antes de transmitir, para não deixar
  -- clientes numa escala diferente da que o host consegue iniciar.
  local current = omsi.duty.get() or {}
  if current.line ~= nil or current.tour ~= nil or current.trip ~= nil then
    toast("Despacho cancelado: você já está em uma escala. Termine-a antes de despachar outra.", 8)
    return
  end

  if omsi.lan.active() then
    local players = omsi.lan.players() or {}
    local sent, send_result, send_reason = pcall(omsi.lan.send, 0, payload)
    if not sent or send_result ~= true then
      toast("Não foi possível enviar o despacho: " .. tostring(send_reason or send_result), 7)
      return
    end
    toast("Despacho enviado: linha " .. line .. ", viagem " .. tour .. " (" .. tostring(#players + 1) .. " jogadores na sessão).", 7)
  end

  local called, start_result, start_reason = pcall(omsi.duty.start, line, tour)
  if called and start_result ~= false then
    toast("Despacho aplicado localmente: linha " .. line .. ", viagem " .. tour, 6)
  else
    toast("Não foi possível iniciar a escala: " .. tostring(start_reason or start_result), 7)
  end
end

omsi.on("key", function(key, down)
  if not down or not enabled then return end
  if key == "F4" then
    roster_visible = not roster_visible
    render_roster()
  elseif key == "F5" then
    dispatch_default_duty()
  elseif key == "F7" and cfg("show_status", true) then
    local s = snapshot()
    toast(string.format("%s | %s | %d XP | Nota %d | Linha %s | Viagem %s | %.0f km/h | atraso %ds",
      s.player, career.rank, career.xp, career.score, s.line, s.trip, s.speed, math.floor(s.delay)), 8)
    if career.score < (tonumber(cfg("minimum_score", 70)) or 70) then
      toast("Nota abaixo do mínimo recomendado (" .. tostring(cfg("minimum_score", 70)) .. "). Revise segurança e pontualidade.", 6)
    end
  elseif key == "F6" then
    persist()
    omsi.save()
    omsi.game.notify("Registros locais salvos.", "info", 4)
  end
end)

omsi.on("duty_start", function(line, tour)
  last_delay_level = 0
  record("duty", { line = line, tour = tour })
  toast("Escala iniciada: linha " .. tostring(line or "—") .. ", viagem " .. tostring(tour or "—"), 5)
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

  if e.k == "dispatch" then
    -- Apenas clientes podem aceitar comandos de despacho; o host nunca aceita comandos de clientes.
    if is_host or tonumber(from) ~= 1 or cfg("auto_accept_dispatch", true) ~= true then return end
    local line = type(e.l) == "string" and e.l:gsub("|", ""):sub(1, 20) or ""
    local tour = type(e.t) == "string" and e.t:gsub("|", ""):sub(1, 20) or ""
    if line == "" or tour == "" then return end
    local min_score = tonumber(cfg("dispatch_minimum_score", 50)) or 50
    if career.score < min_score then
      toast("Despacho recusado: sua nota está abaixo do mínimo da empresa.", 7)
      return
    end
    local current = omsi.duty.get() or {}
    if current.line ~= nil or current.tour ~= nil or current.trip ~= nil then
      toast("Despacho recusado: você já está em uma escala. Termine-a antes de aceitar outra.", 8)
      return
    end
    local called, start_result, why = pcall(omsi.duty.start, line, tour)
    if called and start_result ~= false then
      toast("Despacho recebido: linha " .. line .. ", viagem " .. tour, 7)
    else
      toast("Falha ao iniciar despacho: " .. tostring(why or start_result), 7)
    end
    return
  end

  if not ({ duty = true, arrive = true, depart = true, crash = true, speed = true })[e.k] then return end
  if type(e.i) ~= "string" or #e.i > 24 then return end

  if is_host and cfg("host_authoritative", true) then
    -- O host valida o remetente, elimina reenvios e atribui a sequência oficial.
    if tonumber(from) == 1 then return end
    for _, previous in ipairs(events) do
      if previous.i == e.i then return end
    end
    seq = seq + 1
    e.q = seq
    e.p = tonumber(from) or e.p
    events[#events + 1] = e
    persist()
    local payload = omsi.json.encode(e)
    if #payload <= 120 and not payload:find("|", 1, true) then omsi.lan.send(0, payload) end
  else
    if tonumber(from) ~= 1 or not tonumber(e.q) then return end
    local last = tonumber(omsi.storage.get("last_host_seq")) or 0
    if e.q <= last then return end

    -- O cliente já gravou o evento local antes de enviá-lo ao host.
    -- Atualiza esse registro com a sequência oficial em vez de duplicá-lo.
    local already_local = false
    for _, previous in ipairs(events) do
      if previous.i == e.i then
        previous.q = e.q
        previous.p = e.p
        already_local = true
        break
      end
    end
    if not already_local then events[#events + 1] = e end
    omsi.storage.set("last_host_seq", e.q)
    persist()
  end
end)

omsi.every(2, evaluate_rules)
