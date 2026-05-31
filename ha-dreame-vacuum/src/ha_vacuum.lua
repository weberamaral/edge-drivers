local battery = require "battery"
local mode = require "mode"
local rvcOperatingState = require "rvcOperatingState"
local serviceArea = require "serviceArea"
local fan_speed = require "fanSpeed"
local suction_mode = require "suctionMode"
local current_room = require "rvcCurrentRoom"

local ha_vacuum = {}

function ha_vacuum.find_entity(states, entity_id)
  if not states then
    return nil
  end

  for _, entity in ipairs(states) do
    if entity.entity_id == entity_id then
      return entity
    end
  end

  return nil
end

function ha_vacuum.emit_state(device, entity)
  if not entity then
    print("Vacuum não encontrado")
    return
  end

  print("Vacuum encontrado")
  print("Entity:", entity.entity_id)

  rvcOperatingState.emit_robot_state(device, entity)
  battery.emit_battery(device, entity)
  mode.emit_cleaning_mode(device, entity)
  fan_speed.emit_fan_speed(device, entity)
  suction_mode.emit_suction_mode(device, entity)
  serviceArea.emit_service_areas(device, entity)
  serviceArea.emit_selected_areas(device)
  current_room.emit_current_room(device, entity)
end

return ha_vacuum
