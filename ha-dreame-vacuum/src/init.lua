local Driver = require "st.driver"
local capabilities = require "st.capabilities"
local cosock = require "cosock"
local ServiceArea = capabilities.serviceArea

local service_area = require "serviceArea.utilsArea"
local ha_ws = require "ha.ha_ws"
local ha_vacuum = require "ha_vacuum"
local ha_ws_persistent = require "ha.ha_ws_persistent"
local fan_speed = require "fanSpeed"
local suction_mode = require "suctionMode"
local mode = require "mode"

local function get_ha_host(device)
  return device.preferences.haHost
end

local function get_ha_port(device)
  return tonumber(device.preferences.haPort) or 8123
end

local function get_ha_token(device)
  return device.preferences.haToken
end

local function get_vacuum_entity_id(device)
  return device.preferences.vacuumEntityId or "vacuum.max"
end

local function get_cleaning_mode_entity_id(device)
  return device.preferences.cleaningModeEntityId
end

local function get_water_volume_entity_id(device)
  return device.preferences.waterVolumeEntityId
end

local DEVICE_NETWORK_ID = "ha-ws-vacuum-003"

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------

local function join_numbers(values)
  local parts = {}

  for _, value in ipairs(values) do
    table.insert(parts, tostring(value))
  end

  return table.concat(parts, ",")
end

local function is_ha_configured(device)
  local host = device.preferences.haHost
  local token = device.preferences.haToken
  if not host or host == "" then
    print("HA Host não configurado nas preferences")
    return false
  end
  if not token or token == "" then
    print("HA Token não configurado nas preferences")
    return false
  end
  return true
end

----------------------------------------------------------------
-- CONNECTION
----------------------------------------------------------------

local function handle_ha_state_changed(device, entity_id, new_state)
  if not entity_id or not new_state then
    return
  end

  print("Evento HA recebido:", entity_id)

  if entity_id == get_vacuum_entity_id(device) then
    device:set_field("last_vacuum_state", new_state, { persist = false })

    ha_vacuum.emit_state(device, new_state)

    return
  end

  local cached_vacuum_state = device:get_field("last_vacuum_state")

  if not cached_vacuum_state then
    print("Sem cache do vacuum. Ignorando evento auxiliar:", entity_id)

    return
  end

  cached_vacuum_state.attributes = cached_vacuum_state.attributes or {}

  if entity_id == get_cleaning_mode_entity_id(device) then
    cached_vacuum_state.attributes.cleaning_mode =

        mode.map_select_cleaning_mode_to_ha_attr(new_state.state)

    print("Atualizando cleaning_mode via cache:", tostring(cached_vacuum_state.attributes.cleaning_mode))

    ha_vacuum.emit_state(device, cached_vacuum_state)

    return
  end

  if entity_id == get_water_volume_entity_id(device) then
    cached_vacuum_state.attributes.water_volume =

        fan_speed.map_select_water_volume_to_ha_attr(new_state.state)

    print("Atualizando water_volume via cache:", tostring(cached_vacuum_state.attributes.water_volume))

    ha_vacuum.emit_state(device, cached_vacuum_state)

    return
  end
end

local function start_persistent_ws(device)
  if device:get_field("ha_ws_started") == true then
    print("WebSocket persistente já iniciado")
    return
  end

  if not is_ha_configured(device) then
    print("HA não configurado. WebSocket persistente não iniciado.")
    return
  end

  device:set_field("ha_ws_started", true, { persist = false })

  local config = {
    host = get_ha_host(device),
    port = get_ha_port(device),
    token = get_ha_token(device),
    vacuum_entity_id = get_vacuum_entity_id(device),
    cleaning_mode_entity_id = get_cleaning_mode_entity_id(device),
    water_volume_entity_id = get_water_volume_entity_id(device)
  }

  ha_ws_persistent.start(device, config, function(device, entity_id, new_state)
    handle_ha_state_changed(device, entity_id, new_state)
  end)
end

----------------------------------------------------------------
-- REFRESH STATE
----------------------------------------------------------------

local function refresh_vacuum_state(device)
  cosock.spawn(function()
    print("======================================")
    print("Refresh vacuum via HA WebSocket")
    print("======================================")

    if not is_ha_configured(device) then
      print("Configuração HA incompleta. Abortando refresh.")
      return
    end

    local states, err = ha_ws.connect_auth_and_get_states(
      get_ha_host(device),
      get_ha_port(device),
      get_ha_token(device)
    )

    if not states then
      print("Erro buscando estados:", err)
      return
    end

    local entity = ha_vacuum.find_entity(
      states,
      get_vacuum_entity_id(device)
    )

    device:set_field("last_vacuum_state", entity, { persist = false })
    ha_vacuum.emit_state(device, entity)
  end, "ha-vacuum-refresh")
end

----------------------------------------------------------------
-- POST COMMAND REFRESH
----------------------------------------------------------------

local function refresh_after_command(device)
  cosock.spawn(function()
    local delays = { 2, 10, 30, 60, 120 }
    for _, delay in ipairs(delays) do
      print("Aguardando refresh pós-comando:", delay, "s")
      cosock.socket.sleep(delay)
      refresh_vacuum_state(device)
    end
  end, "ha-vacuum-post-command-refresh")
end

----------------------------------------------------------------
-- SERVICE CALL
----------------------------------------------------------------

local function call_ha_service(device, domain, service, service_data)
  cosock.spawn(function()
    print("======================================")
    print("Executando serviço " .. domain .. "." .. service)
    print("======================================")
    service_data = service_data or {}
    local ok, err = ha_ws.call_service(
      get_ha_host(device),
      get_ha_port(device),
      get_ha_token(device),
      domain,
      service,
      service_data
    )
    if not ok then
      print("Erro executando serviço:", err)

      return
    end

    refresh_after_command(device)
  end, "ha-service-" .. domain .. "-" .. service)
end

local function call_vacuum_service(device, service, service_data)
  service_data = service_data or {}
  service_data.entity_id = get_vacuum_entity_id(device)
  call_ha_service(device, "vacuum", service, service_data)
end

local function clean_selected_areas(device)
  local selected_areas_csv = device:get_field("selected_areas_csv")
  local supported_area_ids_csv = device:get_field("supported_area_ids_csv")

  local selected_areas = service_area.split_area_csv(selected_areas_csv)
  local supported_area_ids = service_area.split_area_csv(supported_area_ids_csv)

  if #selected_areas == 0
      or service_area.are_same_areas(selected_areas, supported_area_ids)
  then
    print("Limpando casa inteira")
    call_vacuum_service(device, "start")
    return
  end

  print("Limpando cômodos selecionados:", service_area.join_numbers(selected_areas))

  call_ha_service(device, "dreame_vacuum", "vacuum_clean_segment", {
    entity_id = get_vacuum_entity_id(device),
    segments = selected_areas
  })
end

----------------------------------------------------------------
-- DISCOVERY
----------------------------------------------------------------

local function discovery_handler(driver, _, should_continue)
  print("Discovery iniciado")

  if should_continue ~= nil and not should_continue() then
    print("Discovery cancelado")
    return
  end

  local device_info = {
    type = "LAN",
    device_network_id = DEVICE_NETWORK_ID,
    label = "HA Vacuum Max",
    profile = "dreame-ha-rvc",
    manufacturer = "Dreame Technology Co., Ltd.",
    model = "D10 Plus Gen 2",
    vendor_provided_label = "Dreame Tech"
  }

  local ok, err = driver:try_create_device(device_info)

  if ok then
    print("Device criado ou já existente")
  else
    print("Erro criando device:", err)
  end
end

----------------------------------------------------------------
-- LIFECYCLE
----------------------------------------------------------------

local function device_added(driver, device)
  print("Device adicionado:", device.label)
  refresh_vacuum_state(device)
end

local function device_init(driver, device)
  print("Device inicializado:", device.label)
  device:emit_event(
    capabilities.healthCheck.healthStatus("offline")
  )
  start_persistent_ws(device)
  refresh_vacuum_state(device)
end

----------------------------------------------------------------
-- COMMAND HANDLERS
----------------------------------------------------------------

local function handle_refresh(driver, device, command)
  print("Refresh recebido")
  refresh_vacuum_state(device)
end

local function handle_start(_, device, _)
  print("Comando START recebido")
  clean_selected_areas(device)
end

local function handle_pause(driver, device, command)
  print("Comando PAUSE recebido")
  call_vacuum_service(device, "pause")
end

local function handle_go_home(driver, device, command)
  print("Comando GO HOME recebido")
  call_vacuum_service(device, "return_to_base")
end

local function handle_set_mode(_, device, command)
  local args = command.args or {}
  local m = args.mode or args[1]
  print("Comando SET MODE recebido:", tostring(m))
  if not m then
    print("Modo não informado no comando setMode")
    return
  end
  local ha_mode = mode.map_st_cleaning_mode_to_ha(m)
  print("Modo HA:", ha_mode)
  call_ha_service(device, "select", "select_option", {
    entity_id = get_cleaning_mode_entity_id(device),
    option = ha_mode
  })
end

local function handle_select_area(_, device, command)
  local args = command.args or {}

  local areas = args.areas or args[1]

  if type(areas) ~= "table" then
    print("Áreas não informadas")

    return
  end

  local selected_areas = {}

  for _, area_id in ipairs(areas) do
    local numeric_area_id = tonumber(area_id)

    if numeric_area_id then
      table.insert(selected_areas, numeric_area_id)
    end
  end

  if #selected_areas == 0 then
    print("Nenhuma área válida selecionada")

    return
  end

  local selected_areas_csv = join_numbers(selected_areas)

  print("Áreas selecionadas:", selected_areas_csv)

  device:set_field(

    "selected_areas_csv",

    selected_areas_csv,

    { persist = true }

  )

  device:emit_event(

    ServiceArea.selectedAreas(selected_areas)

  )
end

local function handle_set_fan_speed(_, device, command)
  local args = command.args or {}
  local speed = args.speed or args.fanSpeed or args[1]
  if type(speed) == "table" then
    speed = speed.value
  end
  print("Comando SET FAN SPEED recebido:", tostring(speed))
  local ha_volume = fan_speed.map_fan_speed_to_ha_water(speed)
  call_ha_service(device, "select", "select_option", {
    entity_id = get_water_volume_entity_id(device),
    option = ha_volume
  })
end

local function handle_set_fan_oscillation(_, device, command)
  local args = command.args or {}

  local mode = args.mode or args.fanOscillationMode or args[1]

  if type(mode) == "table" then
    mode = mode.value
  end

  print("Comando SET FAN OSCILLATION recebido:", tostring(mode))

  local ha_level = suction_mode.map_oscillation_to_ha_suction(mode)

  call_vacuum_service(device, "set_fan_speed", {

    fan_speed = ha_level

  })
end

----------------------------------------------------------------
-- DRIVER
----------------------------------------------------------------

local driver = Driver("ha-ws-vacuum", {
  discovery = discovery_handler,

  lifecycle_handlers = {
    added = device_added,
    init = device_init
  },

  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh
    },
    [ServiceArea.ID] = {
      [ServiceArea.commands.selectAreas.NAME] = handle_select_area
    },
    [capabilities.mode.ID] = {
      [capabilities.mode.commands.setMode.NAME] = handle_set_mode
    },
    [capabilities.robotCleanerOperatingState.ID] = {
      ["start"] = handle_start,
      ["pause"] = handle_pause,
      ["goHome"] = handle_go_home,
      ["returnToHome"] = handle_go_home
    },
    [capabilities.fanSpeed.ID] = {
      [capabilities.fanSpeed.commands.setFanSpeed.NAME] = handle_set_fan_speed
    },
    [capabilities.fanOscillationMode.ID] = {
      [capabilities.fanOscillationMode.commands.setFanOscillationMode.NAME] = handle_set_fan_oscillation
    },
  }
})

----------------------------------------------------------------
-- RUN
----------------------------------------------------------------

driver:run()
