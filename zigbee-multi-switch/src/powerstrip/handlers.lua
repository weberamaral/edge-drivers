local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local log = require "log"

local M = {}

--------------------------------------------------
-- MAIN SWITCH
--------------------------------------------------

function M.main_on(_, device)
  log.info("MAIN ON PRESSED")

  for ep = 1, 4 do
    device:send(
      clusters.OnOff.server.commands.On(device):to_endpoint(ep)
    )
  end

  device:emit_component_event(
    device.profile.components.main,
    capabilities.switch.switch.on()
  )
end

function M.main_off(_, device)
  log.info("MAIN OFF PRESSED")

  for ep = 1, 4 do
    device:send(
      clusters.OnOff.server.commands.Off(device):to_endpoint(ep)
    )
  end

  device:emit_component_event(
    device.profile.components.main,
    capabilities.switch.switch.off()
  )
end

return M
