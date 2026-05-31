local M = {}

M.DEFAULT_SERVICE_AREA_IDS = {
  1, 2, 3, 4, 6, 7, 8, 9
}

function M.split_area_csv(csv)
  local areas = {}

  if not csv or csv == "" then
    return areas
  end

  for value in string.gmatch(csv, "([^,]+)") do
    local area_id = tonumber(value)

    if area_id then
      table.insert(areas, area_id)
    end
  end

  return areas
end

function M.join_numbers(values)
  local parts = {}

  for _, value in ipairs(values) do
    table.insert(parts, tostring(value))
  end

  return table.concat(parts, ",")
end

function M.is_all_areas_selected(selected_areas)
  if #selected_areas ~= #M.DEFAULT_SERVICE_AREA_IDS then
    return false
  end

  local lookup = {}

  for _, area_id in ipairs(selected_areas) do
    lookup[area_id] = true
  end

  for _, area_id in ipairs(M.DEFAULT_SERVICE_AREA_IDS) do
    if lookup[area_id] ~= true then
      return false
    end
  end

  return true
end

function M.build_service_areas_from_entity(entity)
  local attrs = entity.attributes or {}
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

  local service_areas = {}
  local ids = {}

  if type(rooms) == "table" then
    table.sort(rooms, function(a, b)
      return tostring(a.name or "") < tostring(b.name or "")
    end)

    for _, room in ipairs(rooms) do
      local id = tonumber(room.id)
      local name = room.name

      if id and name then
        table.insert(service_areas, {
          areaId = id,
          areaName = name
        })

        table.insert(ids, id)
      end
    end
  end

  return service_areas, ids
end

function M.are_same_areas(selected_areas, default_areas)
  if #selected_areas ~= #default_areas then
    return false
  end

  local lookup = {}

  for _, area_id in ipairs(selected_areas) do
    lookup[area_id] = true
  end

  for _, area_id in ipairs(default_areas) do
    if lookup[area_id] ~= true then
      return false
    end
  end

  return true
end

return M
