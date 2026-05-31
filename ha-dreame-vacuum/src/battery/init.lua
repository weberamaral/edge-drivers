local capabilities = require "st.capabilities"

local battery = {}

function battery.emit_battery(device, entity)
  local attrs = entity.attributes or {}
  local battery = attrs.battery or attrs.battery_level
  if battery then
    battery = tonumber(battery)
    if battery then
      device:emit_event(capabilities.battery.battery(battery))
      return
    end
  end
end

return battery
