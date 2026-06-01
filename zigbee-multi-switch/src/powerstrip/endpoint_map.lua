local M = {}

local COMPONENT_TO_ENDPOINT = {
  switch1 = 1,
  switch2 = 2,
  switch3 = 3,
  switch4 = 4
}

local ENDPOINT_TO_COMPONENT = {
  [1] = "switch1",
  [2] = "switch2",
  [3] = "switch3",
  [4] = "switch4"
}

function M.component_to_endpoint(_, component_id)
  return COMPONENT_TO_ENDPOINT[component_id]
end

function M.endpoint_to_component(_, ep)
  return ENDPOINT_TO_COMPONENT[ep] or "main"
end

return M
