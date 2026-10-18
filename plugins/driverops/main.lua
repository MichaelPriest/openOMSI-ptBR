-- DriverOps for openOMSI 0.3.37+
-- Install at <openOMSI content root>/plugins/driverops/main.lua.
-- Uses the public Lua plugin API; does not modify the game or OMSI content.

local PANEL = "driverops"
local panel_visible = false

local function safe_text(value, fallback)
  if value == nil or value == "" then return fallback end
  return tostring(value)
end

local function operational_snapshot()
  local info = omsi.info() or {}
  local bus = omsi.bus.state() or {}
  local duty = omsi.duty.get() or {}
  local next_stop = duty.next_stop
  local next_stop_name = type(next_stop) == "table" and next_stop.name or info.next_stop
  local speed = bus.speed
  if type(speed) ~= "number" then speed = omsi.speed() or info.speed or 0 end
  local delay = duty.delay
  if type(delay) ~= "number" then delay = info.delay end
  local delay_text = type(delay) == "number" and omsi.fmt.delay(delay) or "Sem tabela"
  local passengers = omsi.bus.passengers()
  local passenger_text = type(passengers) == "number" and tostring(passengers) or "—"

  if not omsi.has_vehicle() then
    return {
      vehicle = "Entre em um ônibus para iniciar",
      line = "—",
      tour = "—",
      speed = "—",
      delay = "—",
      next_stop = "Nenhuma viagem ativa",
      passengers = "—",
    }
  end

  return {
    vehicle = safe_text(omsi.vehicle(), "Veículo não identificado"),
    line = safe_text(duty.line or info.line, "Sem linha"),
    tour = safe_text(duty.tour or info.tour, "Sem tabela"),
    speed = string.format("%.0f km/h", math.abs(speed)),
    delay = delay_text,
    next_stop = safe_text(next_stop_name, "Sem próxima parada"),
    passengers = passenger_text,
  }
end

local function render_panel()
  local s = operational_snapshot()
  local panel = {
    anchor = "top_left",
    x = 18,
    y = 72,
    width = 340,
    padding = 14,
    gap = 7,
    background = "#111827F2",
    radius = 14,
    accent = "#22C55E",
    visible = panel_visible,
    draggable = true,
    children = {
      { type = "row", children = {
        { type = "icon", name = "directions_bus", color = "#22C55E", size = 22 },
        { type = "text", text = "DRIVEROPS", size = 17, weight = "bold", grow = true },
        { type = "badge", text = s.speed, color = "#22C55E", text_color = "#07130A" },
      } },
      { type = "text", text = s.vehicle, size = 13, color = "#D1D5DB" },
      { type = "divider" },
      { type = "row", children = {
        { type = "text", text = "Linha", color = "#9CA3AF", grow = true },
        { type = "text", text = s.line, weight = "bold" },
        { type = "space", size = 12 },
        { type = "text", text = "Viagem", color = "#9CA3AF" },
        { type = "text", text = s.tour, weight = "bold" },
      } },
      { type = "row", children = {
        { type = "text", text = "Atraso", color = "#9CA3AF", grow = true },
        { type = "text", text = s.delay, weight = "bold" },
        { type = "space", size = 12 },
        { type = "icon", name = "groups", color = "#60A5FA" },
        { type = "text", text = s.passengers },
      } },
      { type = "text", text = "PRÓXIMA PARADA", size = 10, color = "#9CA3AF", weight = "bold" },
      { type = "text", text = s.next_stop, size = 15, weight = "medium" },
      { type = "text", text = "F9: mostrar/ocultar painel  •  F8: resumo rápido", size = 10, color = "#9CA3AF" },
    },
  }
  local ok, why = omsi.ui.set(PANEL, panel)
  if not ok and why then
    omsi.message("DriverOps: não foi possível atualizar o painel: " .. tostring(why), 5)
  end
end

omsi.on("key", function(key, down)
  if not down then return end
  if key == "F9" then
    panel_visible = not panel_visible
    render_panel()
  elseif key == "F8" then
    local s = operational_snapshot()
    omsi.ui.toast(
      string.format("%s | Linha %s | %s | %s", s.speed, s.line, s.delay, s.next_stop),
      { title = "DriverOps", icon = "directions_bus", color = "#22C55E", seconds = 6 }
    )
  end
end)

omsi.on("start", function()
  render_panel()
  omsi.message("DriverOps 0.3.37 carregado | F9: painel • F8: resumo", 6)
end)

omsi.every(1, function()
  render_panel()
end)
