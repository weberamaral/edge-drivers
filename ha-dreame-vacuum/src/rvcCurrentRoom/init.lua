local capabilities = require "st.capabilities"
local CurrentRoom = capabilities["signalprogram56169.rvcCurrentRoom"]

local current_room = {}

local function find_room_name_by_id(attrs, room_id)
  if not room_id then
    return nil
  end

  room_id = tonumber(room_id)

  if not room_id then
    return nil
  end

  local rooms_by_map = attrs.rooms or {}
  local selected_map = attrs.selected_map

  local rooms = nil

  if selected_map and rooms_by_map[selected_map] then
    rooms = rooms_by_map[selected_map]
  else
    for _, map_rooms in pairs(rooms_by_map) do
      rooms = map_rooms
      break
    end
  end

  if type(rooms) ~= "table" then
    return nil
  end

  for _, room in ipairs(rooms) do
    if tonumber(room.id) == room_id then
      return room.name
    end
  end

  return nil
end

local function resolve_current_room(attrs)
  local direct =
      attrs.current_room
      or attrs.current_room_name
      or attrs.cleaning_room
      or attrs.room_name

  if direct and direct ~= "" then
    return tostring(direct)
  end

  local room_id =
      attrs.current_room_id
      or attrs.current_segment
      or attrs.segment
      or attrs.cleaning_segment
      or attrs.current_room

  local room_name = find_room_name_by_id(attrs, room_id)

  if room_name then
    return room_name
  end

  return "Não identificado"
end

function current_room.emit_current_room(device, entity)
  local attrs = entity.attributes or {}

  local room = resolve_current_room(attrs)

  print("Cômodo atual:", room)

  device:emit_event(
    CurrentRoom.currentRoom(room)
  )
end

return current_room
