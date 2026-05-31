local capabilities = require "st.capabilities"
local log = require "log"

return function(device, value)
  log.info(string.format("window_shade state=%s", tostring(value)))

  if value == 0 then
    device:emit_event(capabilities.windowShade.windowShade.opening())
  elseif value == 2 then
    device:emit_event(capabilities.windowShade.windowShade.closing())
  elseif value == 1 then
    log.info("window_shade stopped")
  end
end
