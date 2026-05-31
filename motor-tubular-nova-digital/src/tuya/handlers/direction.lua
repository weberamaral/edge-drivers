local log = require "log"

return function(device, value)
  local direction = value == 1 and "back" or "forward"
  log.info(string.format("direction received=%s", direction))
  device:set_field("current_direction", direction, { persist = true })
end
