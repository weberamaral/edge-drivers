local capabilities = require "st.capabilities"
local FanSpeed = capabilities.fanSpeed

local fan_speed = {}

local function map_ha_water_to_fan_speed(value)
  if value == "Low" then
    return 1
  elseif value == "Medium" then
    return 2
  elseif value == "High" then
    return 3
  end

  return 2
end

function fan_speed.map_select_water_to_ha_water(value)
  if value == "low" then
    return "Low"
  elseif value == "medium" then
    return "Medium"
  elseif value == "high" then
    return "High"
  end

  return value
end

function fan_speed.map_fan_speed_to_ha_water(value)
  value = tonumber(value)

  if value == 1 then
    return "low"
  elseif value == 2 then
    return "medium"
  elseif value == 3 then
    return "high"
  end

  return "medium"
end

function fan_speed.emit_fan_speed(device, entity)
  local attrs = entity.attributes or {}
  local speed = map_ha_water_to_fan_speed(attrs.water_volume)
  print("Volume de Água: ", tostring(attrs.water_volume))
  device:emit_event(FanSpeed.fanSpeed(speed))
end

return fan_speed
