local capabilities = require "st.capabilities"
local Mode = capabilities.mode

local mode = {}

local function map_select_cleaning_mode_to_ha_attr(value)
  if value == "mopping" then
    return "Mopping"
  elseif value == "sweeping_and_mopping" then
    return "Sweeping and mopping"
  elseif value == "sweeping" then
    return "Sweeping"
  end

  return value
end

local function map_ha_cleaning_mode_to_st(value)
  if value == "Mopping" then
    return "Passar pano"
  elseif value == "Sweeping and mopping" then
    return "Aspirar e passar pano"
  elseif value == "Sweeping" then
    return "Aspirar"
  end

  return value
end

function mode.map_select_mode_to_ha_mode(value)
  if value == "mopping" then
    return "Mopping"
  elseif value == "sweeping_and_mopping" then
    return "Sweeping and mopping"
  elseif value == "sweeping" then
    return "Sweeping"
  end

  return value
end

function mode.map_st_cleaning_mode_to_ha(value)
  if value == "Passar pano" then
    return "mopping"
  elseif value == "Aspirar e passar pano" then
    return "sweeping_and_mopping"
  elseif value == "Aspirar" then
    return "sweeping"
  end

  return "sweeping_and_mopping"
end

function mode.emit_cleaning_mode(device, entity)
  local attrs = entity.attributes or {}

  local supported_modes = {}

  for _, ha_mode in ipairs(attrs.cleaning_mode_list or {}) do
    local st_mode = map_ha_cleaning_mode_to_st(ha_mode)

    if st_mode and st_mode ~= "" then
      table.insert(supported_modes, st_mode)
    end
  end

  if #supported_modes == 0 then
    table.insert(supported_modes, "sweeping")
  end

  local current_mode = map_ha_cleaning_mode_to_st(attrs.cleaning_mode)

  print("Modo: ", tostring(current_mode))
  print("Modos suportados:", table.concat(supported_modes, ", "))

  device:emit_event(Mode.supportedModes(supported_modes))
  device:emit_event(Mode.supportedArguments(supported_modes))
  device:emit_event(Mode.mode(current_mode))
end

return mode
