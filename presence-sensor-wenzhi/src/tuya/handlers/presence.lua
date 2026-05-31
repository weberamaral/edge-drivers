local capabilities = require "st.capabilities"

return function(device, value)
  if value == 1 or value == 2 then
    device:emit_event(
      capabilities.presenceSensor.presence.present()
    )
  else
    device:emit_event(
      capabilities.presenceSensor.presence.not_present()
    )
  end
end
