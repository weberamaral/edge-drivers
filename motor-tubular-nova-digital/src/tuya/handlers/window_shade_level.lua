local capabilities = require "st.capabilities"
local log = require "log"

return function(device, value)
  local level = tonumber(value)
  log.info(string.format("window_shade_level received value=%s", tostring(value)))

  if not level then
    return
  end

  local st_level = level
  log.info(string.format("window_shade_level ST value=%d", st_level))
  device:emit_event(capabilities.windowShadeLevel.shadeLevel(st_level))

  -------------------------------------------------
  -- SHADE STATE
  -------------------------------------------------

  if st_level == 0 then
    device:emit_event(capabilities.windowShade.windowShade.closed())
  elseif st_level == 100 then
    device:emit_event(capabilities.windowShade.windowShade.open())
  else
    device:emit_event(capabilities.windowShade.windowShade.partially_open())
  end
end
