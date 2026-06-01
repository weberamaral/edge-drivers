local capabilities = require "st.capabilities"

local M = {}

local SWITCHES = {
  "switch1",
  "switch2",
  "switch3",
  "switch4"
}

function M.update_main_switch(device)
  local any_on = false

  for _, component in ipairs(SWITCHES) do
    local value =
        device:get_latest_state(
          component,
          capabilities.switch.ID,
          capabilities.switch.switch.NAME
        )

    if value == "on" then
      any_on = true
      break
    end
  end

  if any_on then
    device:emit_event_for_endpoint(
      1,
      capabilities.switch.switch.on()
    )
  else
    device:emit_event_for_endpoint(
      1,
      capabilities.switch.switch.off()
    )
  end
end

return M
