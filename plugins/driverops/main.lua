-- DriverOps: real-time operational snapshot for openOMSI.
-- Install as <OMSI content root>/plugins/driverops/main.lua.
-- Uses only the live game state exposed by the documented Lua plugin API.

local function clean(value, fallback)
  if value == nil or value == "" then return fallback end
  return tostring(value)
end

local function format_delay(seconds)
  if type(seconds) ~= "number" then return "indisponível" end
  local sign = seconds < 0 and "adiantado " or "atrasado "
  local total = math.floor(math.abs(seconds) + 0.5)
  return sign .. string.format("%02d:%02d", math.floor(total / 60), total % 60)
end

local function show_operations()
  if not omsi.has_vehicle() then
    omsi.message("DriverOps | Entre em um ônibus para consultar a operação.", 5)
    return
  end

  local info = omsi.info() or {}
  local vehicle = clean(omsi.vehicle(), "Veículo não identificado")
  local line = clean(info.line, "Sem linha")
  local tour = clean(info.tour, "Sem tabela")
  local next_stop = clean(info.next_stop, "Sem próxima parada")
  local speed = omsi.speed() or info.speed or 0
  local delay = format_delay(info.delay)

  local report = string.format(
    "DRIVEROPS | %s\nLinha %s • Viagem %s\nVelocidade: %.0f km/h | %s\nPróxima parada: %s",
    vehicle, line, tour, math.abs(speed), delay, next_stop
  )
  omsi.message(report, 9)
end

local function show_quick_status()
  if not omsi.has_vehicle() then
    omsi.message("DriverOps | Nenhum ônibus ativo.", 4)
    return
  end

  local info = omsi.info() or {}
  omsi.message(string.format(
    "DriverOps | %.0f km/h | Linha %s | Próxima: %s",
    math.abs(omsi.speed() or info.speed or 0),
    clean(info.line, "—"),
    clean(info.next_stop, "não informada")
  ), 5)
end

omsi.on("key", function(key, down)
  if not down then return end
  if key == "F9" then
    show_operations()
  elseif key == "F10" then
    show_quick_status()
  end
end)

omsi.on("start", function()
  omsi.message("DriverOps carregado | F9: operação completa • F10: status rápido", 6)
end)
