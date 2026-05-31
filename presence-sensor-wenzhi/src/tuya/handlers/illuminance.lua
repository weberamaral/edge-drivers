local capabilities = require "st.capabilities"

return function(device, value)
  local lux = tonumber(value)

  if not lux then
    return
  end

  if lux < 0 then
    lux = 0
  end

  -------------------------------------------------
  -- DELTA FILTER
  -------------------------------------------------

  local last_lux = device:get_field("last_lux")

  if last_lux then
    local diff = math.abs(last_lux - lux)

    if diff < 20 then
      return
    end
  end

  device:set_field("last_lux", lux)

  -------------------------------------------------
  -- EMIT
  -------------------------------------------------

  device:emit_event(capabilities.illuminanceMeasurement.illuminance(lux))
end
