local log = require "log"

local profiles = {
  ["_TZE204_gkfbdvyx"] = require "tuya.profiles._TZE204_gkfbdvyx",
}

local handlers = {
  presence = require "tuya.handlers.presence",
  illuminance = require "tuya.handlers.illuminance",
}

local dispatcher = {}

-------------------------------------------------
-- GET PROFILE
-------------------------------------------------

function dispatcher.get_profile(device)
  local manufacturer = device:get_manufacturer()
  return profiles[manufacturer]
end

-------------------------------------------------
-- HANDLE DP
-------------------------------------------------

function dispatcher.handle(device, parsed)
  if not parsed then
    return
  end

  local manufacturer = device:get_manufacturer()
  local profile = profiles[manufacturer]

  if not profile then
    return
  end

  local dp_config = profile[parsed.dp]

  if not dp_config then
    return
  end

  local handler = handlers[dp_config.handler]

  if handler then
    log.info(
      string.format(
        "Dispatcher manufacturer=%s dp=%s handler=%s value=%s",
        tostring(manufacturer),
        tostring(parsed.dp),
        tostring(dp_config.handler),
        tostring(parsed.value)
      )
    )
    handler(device, parsed.value)
  end
end

return dispatcher
