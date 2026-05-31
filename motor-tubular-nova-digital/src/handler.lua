local dispatcher = require "tuya.dispatcher"

local handler = {}

function handler.handle_dp(device, parsed)
  if not parsed then
    return
  end

  dispatcher.handle(device, parsed)
end

function handler.can_handler(opts, driver, device)
  return device:get_manufacturer() == "_TZE600_5cu64znk"
end

return handler
