local capabilities = require "st.capabilities"
local defaults = require "st.zigbee.defaults"

local handlers = require "powerstrip.handlers"
local endpoint_map = require "powerstrip.endpoint_map"

local powerstrip_driver = {
  NAME = "powerstrip",

  supported_capabilities = {
    capabilities.switch,
    capabilities.refresh
  },

  component_to_endpoint =
      endpoint_map.component_to_endpoint,

  endpoint_to_component =
      endpoint_map.endpoint_to_component,

  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] =
          function(driver, device, command)
            if command.component == "main" then
              handlers.main_on(driver, device)
            end
          end,

      [capabilities.switch.commands.off.NAME] =
          function(driver, device, command)
            if command.component == "main" then
              handlers.main_off(driver, device)
            end
          end
    }
  }
}

defaults.register_for_default_handlers(
  powerstrip_driver,
  powerstrip_driver.supported_capabilities
)

return powerstrip_driver
