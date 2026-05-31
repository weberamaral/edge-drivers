local capabilities = require "st.capabilities"
local FanOscillationMode = capabilities.fanOscillationMode

local suction_mode = {}

local function map_ha_suction_to_oscillation(value)
  value = tostring(value)

  if value == "Silent" then
    return "fixed"
  elseif value == "Standard" then
    return "vertical"
  elseif value == "Strong" then
    return "horizontal"
  elseif value == "Turbo" then
    return "all"
  end

  return "vertical"
end

function suction_mode.map_oscillation_to_ha_suction(value)
  if value == "fixed" then
    return "Silent"
  elseif value == "vertical" then
    return "Standard"
  elseif value == "horizontal" then
    return "Strong"
  elseif value == "all" then
    return "Turbo"
  end

  return "Standard"
end

function suction_mode.emit_suction_mode(device, entity)
  local attrs = entity.attributes or {}
  local mode = map_ha_suction_to_oscillation(attrs.suction_level or attrs.fan_speed)

  print("Potência HA:", tostring(attrs.suction_level or attrs.fan_speed))
  print("fanOscillationMode ST:", tostring(mode))

  device:emit_event(

    FanOscillationMode.supportedFanOscillationModes({
      "fixed",
      "vertical",
      "horizontal",
      "all"
    })
  )

  device:emit_event(FanOscillationMode.fanOscillationMode(mode))
end

return suction_mode
