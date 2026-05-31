local dispatcher = require "tuya.dispatcher"

local handler = {}

function handler.handle_dp(device, parsed)
  dispatcher.handle(device, parsed)
end

function handler.can_handler(opts, driver, device)
  return device:get_manufacturer() == "_TZE204_gkfbdvyx"
end

return handler
