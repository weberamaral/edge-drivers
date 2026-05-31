local log = require "log"

local tuya_utils = require "tuya.tuya_utils"
local profiles = { ["_TZE600_5cu64znk"] = require "tuya.profiles._TZE600_5cu64znk", }

local commands = {}

local OPEN = 0;
local PAUSE = 1;
local CLOSE = 2;
local PRESET_LEVEL = 50
local PRESET_LEVEL_KEY = "_presetLevel"

local function get_profile(device)
  local manufacturer = device:get_manufacturer()
  return profiles[manufacturer]
end

-------------------------------------------------
-- OPEN
-------------------------------------------------

function commands.open(driver, device, command)
  log.info("Curtain Open command")
  tuya_utils.write_enum_dp(device, 1, OPEN)
end

-------------------------------------------------
-- CLOSE
-------------------------------------------------

function commands.close(driver, device, command)
  log.info("Curtain Close command")
  tuya_utils.write_enum_dp(device, 1, CLOSE)
end

-------------------------------------------------
-- PAUSE
-------------------------------------------------

function commands.pause(driver, device, command)
  log.info("Curtain Pause command")
  tuya_utils.write_enum_dp(device, 1, PAUSE)
end

-------------------------------------------------
-- SET LEVEL
-------------------------------------------------

function commands.set_level(driver, device, command)
  local level = command.args.shadeLevel
  log.info(string.format("Curtain Set Level: %s", level))
  tuya_utils.write_number_dp(device, 2, level)
end

-------------------------------------------------
-- SET PRESET
-------------------------------------------------

function commands.preset(driver, device, commands)
  log.info(string.format("Curtain Set Level: %s", commands.args.shadeLevel))
  local level = device:get_latest_state("main", "windowShadePreset", "position") or device:get_field(PRESET_LEVEL_KEY) or
      (device.preferences ~= nil and device.preferences.presetPosition) or PRESET_LEVEL
  tuya_utils.write_number_dp(device, 2, level)
end

return commands
