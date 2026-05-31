local capabilities = require "st.capabilities"
local ServiceArea = capabilities.serviceArea
local utilsArea = require "serviceArea.utilsArea"

local serviceArea = {}

function serviceArea.emit_service_areas(device, entity)
  local service_areas, area_ids = utilsArea.build_service_areas_from_entity(entity)

  if #service_areas == 0 then
    print("Nenhum cômodo encontrado no HA")
    return
  end

  local area_ids_csv = utilsArea.join_numbers(area_ids)

  device:set_field(
    "supported_area_ids_csv",
    area_ids_csv,
    { persist = true }
  )

  print("Cômodos disponíveis:", area_ids_csv)

  device:emit_event(
    ServiceArea.supportedAreas(service_areas)
  )
end

function serviceArea.emit_selected_areas(device)
  local selected_areas_csv = device:get_field("selected_areas_csv")
  local supported_area_ids_csv = device:get_field("supported_area_ids_csv")

  local selected_areas = utilsArea.split_area_csv(selected_areas_csv)
  local supported_area_ids = utilsArea.split_area_csv(supported_area_ids_csv)

  if #selected_areas == 0 then
    selected_areas = supported_area_ids

    device:set_field(
      "selected_areas_csv",
      utilsArea.join_numbers(selected_areas),
      { persist = true }
    )
  end

  print("Cômodos selecionados:", utilsArea.join_numbers(selected_areas))

  device:emit_event(
    ServiceArea.selectedAreas(selected_areas)
  )
end

return serviceArea
