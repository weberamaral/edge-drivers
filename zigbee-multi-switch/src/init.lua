local capabilities = require "st.capabilities"
local defaults = require "st.zigbee.defaults"
local ZigbeeDriver = require "st.zigbee"
local clusters = require "st.zigbee.zcl.clusters"

local log = require "log"

local OnOff = clusters.OnOff


--------------------------------------------------
-- ENDPOINT MAP
--------------------------------------------------

local COMPONENT_TO_ENDPOINT = {
  switch1 = 1,
  switch2 = 2,
  switch3 = 3,
  switch4 = 4
}

local ENDPOINT_TO_COMPONENT = {
  [1] = "switch1",
  [2] = "switch2",
  [3] = "switch3",
  [4] = "switch4"
}

local function component_to_endpoint(_, component_id)
  return COMPONENT_TO_ENDPOINT[component_id]
end

local function endpoint_to_component(_, ep)
  local component =
      ENDPOINT_TO_COMPONENT[ep] or "main"

  log.info(
    string.format(
      "EP %s mapped to component %s",
      tostring(ep),
      component
    )
  )

  return component
end

--------------------------------------------------
-- MAIN AGGREGATION
--------------------------------------------------

local switchSummary =
    capabilities["signalprogram56169.switchSummary"]

local function update_aggregated_state(device)
  local count_on = 0

  for i = 1, 4 do
    local component = "switch" .. i

    local value =
        device:get_latest_state(
          component,
          capabilities.switch.ID,
          capabilities.switch.switch.NAME
        )

    if value == "on" then
      count_on = count_on + 1
    end
  end

  --------------------------------------------------
  -- MAIN SWITCH
  --------------------------------------------------

  if count_on > 0 then
    device:emit_event(
      capabilities.switch.switch.on()
    )
  else
    device:emit_event(
      capabilities.switch.switch.off()
    )
  end

  --------------------------------------------------
  -- SUMMARY
  --------------------------------------------------

  local summary

  if count_on == 0 then
    summary = "Nenhuma ligada"
  elseif count_on == 4 then
    summary = "Todas ligadas"
  else
    summary = string.format(
      "%d %s",
      count_on,
      count_on == 1 and "ligada" or "ligadas"
    )
  end

  device:emit_event(switchSummary.summary(summary))
end

--------------------------------------------------
-- CUSTOM ONOFF REPORT HANDLER
--------------------------------------------------

local function onoff_attr_handler(driver, device, value, zb_rx)
  local endpoint = zb_rx.address_header.src_endpoint.value

  local component =
      ENDPOINT_TO_COMPONENT[endpoint]

  if not component then
    return
  end

  local state =
      value.value and
      capabilities.switch.switch.on()
      or
      capabilities.switch.switch.off()

  log.info(
    string.format(
      "EP %d -> %s -> %s",
      endpoint,
      component,
      value.value and "ON" or "OFF"
    )
  )

  device:emit_component_event(
    device.profile.components[component],
    state
  )

  update_aggregated_state(device)
end

--------------------------------------------------
-- SWITCH COMMANDS
--------------------------------------------------

local function switch_on(_, device, command)
  if command.component == "main" then
    log.info("MAIN ON PRESSED")

    for ep = 1, 4 do
      device:send(
        OnOff.server.commands.On(device):to_endpoint(ep)
      )
    end

    return
  end

  local endpoint =
      COMPONENT_TO_ENDPOINT[
      command.component
      ]

  if endpoint then
    device:send(
      OnOff.server.commands.On(device):to_endpoint(endpoint)
    )
  end
end

local function switch_off(_, device, command)
  if command.component == "main" then
    log.info("MAIN OFF PRESSED")

    for ep = 1, 4 do
      device:send(
        OnOff.server.commands.Off(device):to_endpoint(ep)
      )
    end

    return
  end

  local endpoint =
      COMPONENT_TO_ENDPOINT[
      command.component
      ]

  if endpoint then
    device:send(
      OnOff.server.commands.Off(device):to_endpoint(endpoint)
    )
  end
end

--------------------------------------------------
-- REFRESH
--------------------------------------------------

local function refresh_handler(_, device)
  log.info("REFRESH PRESSED")

  for ep = 1, 4 do
    device:send(
      clusters.OnOff.attributes.OnOff:read(device):to_endpoint(ep)
    )
  end
end

--------------------------------------------------
-- DEVICE INIT
--------------------------------------------------

local function device_init(_, device)
  log.info(
    string.format(
      "INITIALIZING %s",
      device.label
    )
  )

  refresh_handler(nil, device)
end

--------------------------------------------------
-- DRIVER
--------------------------------------------------

local driver_template = {
  health_check = false,
  supported_capabilities = {
    capabilities.switch,
    capabilities.refresh
  },

  lifecycle_handlers = {
    init = device_init
  },

  component_to_endpoint = component_to_endpoint,
  endpoint_to_component = endpoint_to_component,

  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = switch_on,
      [capabilities.switch.commands.off.NAME] = switch_off
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler
    },
  },

  zigbee_handlers = {
    attr = {
      [OnOff.ID] = {
        [OnOff.attributes.OnOff.ID] =
            onoff_attr_handler
      }
    }
  }
}

defaults.register_for_default_handlers(
  driver_template,
  {
    capabilities.refresh
  }
)

local zigbee_driver =
    ZigbeeDriver(
      "powerstrip",
      driver_template
    )

zigbee_driver:run()
