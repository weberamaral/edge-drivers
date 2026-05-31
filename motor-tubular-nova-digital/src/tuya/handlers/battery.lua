local capabilities = require "st.capabilities"
local log = require "log"

return function(device, value)
  local battery = tonumber(value)

  log.info(
    string.format("battery received value=%s", tostring(value)))

  if not battery then
    return
  end

  if battery < 0 then
    battery = 0
  end

  if battery > 100 then
    battery = 100
  end

  device:emit_event(
    capabilities.battery.battery(battery)
  )
end
