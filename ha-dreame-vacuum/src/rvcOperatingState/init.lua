local capabilities = require "st.capabilities"
local RVC = capabilities.robotCleanerOperatingState

local rvcOperatingState = {}

local SUPPORTED_STATES = {
  "stopped",
  "running",
  "paused",
  "seekingCharger",
  "charging",
  "docked",
  "unableToStartOrResume",
  "unableToCompleteOperation",
  "commandInvalidInState",
  "failedToFindChargingDock",
  "stuck",
  "dustBinMissing",
  "dustBinFull",
  "waterTankEmpty",
  "waterTankMissing",
  "waterTankLidOpen",
  "mopCleaningPadMissing"
}

local function normalize(value)
  if value == nil then
    return ""
  end
  return string.lower(tostring(value))
end

----------------------------------------------------------------
-- RESOLVERS
----------------------------------------------------------------

local function resolve_active_state(entity)
  local attrs = entity.attributes or {}

  local ha_state = normalize(entity.state)
  local status = normalize(attrs.status)
  local vacuum_state = normalize(attrs.vacuum_state)

  if attrs.paused == true
      or attrs.returning_paused == true
      or ha_state == "paused"
      or status == "paused"
      or vacuum_state == "paused"
  then
    return "paused"
  end

  if attrs.returning == true
      or ha_state == "returning"
      or status == "returning"
      or string.find(vacuum_state, "return")
  then
    return "seekingCharger"
  end

  if attrs.running == true
      or attrs.started == true
      or ha_state == "cleaning"
      or status == "cleaning"
      or status == "room cleaning"
      or attrs.zone_cleaning == true
      or attrs.segment_cleaning == true
      or attrs.spot_cleaning == true
      or attrs.cruising == true
      or string.find(vacuum_state, "sweep")
      or string.find(vacuum_state, "mop")
      or string.find(vacuum_state, "clean")
  then
    return "running"
  end

  return nil
end

local function resolve_docked_state(entity)
  local attrs = entity.attributes or {}

  local ha_state = normalize(entity.state)
  local status = normalize(attrs.status)
  local vacuum_state = normalize(attrs.vacuum_state)

  if attrs.charging == true
      or ha_state == "charging"
      or status == "charging"
      or vacuum_state == "charging"
  then
    return "charging"
  end

  if attrs.docked == true
      or ha_state == "docked"
      or status == "sleeping"
      or status == "idle"
      or vacuum_state == "idle"
      or vacuum_state == "charging_completed"
      or ha_state == "idle"
  then
    return "docked"
  end

  return nil
end

local function resolve_error_state(entity)
  local attrs = entity.attributes or {}

  local error = normalize(
    attrs.error
    or attrs.error_code
    or attrs.fault
    or attrs.warning
    or attrs.status
  )

  if error == ""
      or error == "none"
      or error == "no error"
      or error == "no_error"
      or error == "ok"
  then
    return nil
  end

  if string.find(error, "stuck")
      or string.find(error, "trapped")
      or string.find(error, "wheel")
      or string.find(error, "cliff")
      or string.find(error, "bumper")
  then
    return "stuck"
  end

  if string.find(error, "dust") and string.find(error, "missing") then
    return "dustBinMissing"
  end

  if string.find(error, "dust") and string.find(error, "full") then
    return "dustBinFull"
  end

  if string.find(error, "water") and string.find(error, "empty") then
    return "waterTankEmpty"
  end

  if string.find(error, "water")
      and (
        string.find(error, "missing")
        or string.find(error, "not installed")
        or string.find(error, "not_install")
      )
  then
    return "waterTankMissing"
  end

  if string.find(error, "water") and string.find(error, "lid") then
    return "waterTankLidOpen"
  end

  if string.find(error, "mop")
      and (
        string.find(error, "missing")
        or string.find(error, "not installed")
        or string.find(error, "not_install")
      )
  then
    return "mopCleaningPadMissing"
  end

  if string.find(error, "dock")
      or string.find(error, "charging base")
      or string.find(error, "base station")
      or string.find(error, "failed to return")
  then
    return "failedToFindChargingDock"
  end

  if string.find(error, "invalid")
      or string.find(error, "not allowed")
      or string.find(error, "unsupported")
      or string.find(error, "not supported")
  then
    return "commandInvalidInState"
  end

  if string.find(error, "start")
      or string.find(error, "resume")
      or string.find(error, "unable to start")
  then
    return "unableToStartOrResume"
  end

  return "unableToCompleteOperation"
end

local function resolve_operating_state(entity)
  return resolve_active_state(entity)
      or resolve_docked_state(entity)
      or resolve_error_state(entity)
      or "stopped"
end

----------------------------------------------------------------
-- EMMITTERS
----------------------------------------------------------------

local function emit_supported_commands(device, operating_state)
  local commands = {}

  if operating_state == "docked"
      or operating_state == "stopped"
      or operating_state == "charging"
  then
    commands = { "start" }
  elseif operating_state == "running" then
    commands = { "start", "pause", "goHome" }
  elseif operating_state == "paused" then
    commands = { "start", "pause", "goHome" }
  elseif operating_state == "seekingCharger" then
    commands = { "pause" }
  else
    commands = { "start" }
  end

  device:emit_event(RVC.supportedCommands(commands))
  device:emit_event(RVC.supportedOperatingStateCommands(commands))
end

local function emit_operating_state(device, value)
  print("Status:", value)

  device:emit_event(RVC.supportedOperatingStates(SUPPORTED_STATES))
  device:emit_event(RVC.operatingState(value))

  emit_supported_commands(device, value)
end

----------------------------------------------------------------
-- PUBLIC METHODS
----------------------------------------------------------------

function rvcOperatingState.emit_robot_state(device, entity)
  local operating_state = resolve_operating_state(entity)
  emit_operating_state(device, operating_state)
end

return rvcOperatingState
