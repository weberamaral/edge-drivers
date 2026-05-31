-- Copyright 2026 weberamaral
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
local defaults = require "st.zigbee.defaults"
local ZigbeeDriver = require "st.zigbee"
local capabilities = require "st.capabilities"
local window_shade_preset_defaults = require "st.zigbee.defaults.windowShadePreset_defaults"
local clusters = require "st.zigbee.zcl.clusters"
local device_management = require "st.zigbee.device_management"

local Basic = clusters.Basic

local log = require "log"

local tuya_utils = require "tuya.tuya_utils"
local tuya_protocol = require "tuya.tuya_protocol"

local handlers = require "handler"
local commands = require "commands"

local PRESET_LEVEL = 50
local PRESET_LEVEL_KEY = "_presetLevel"

-------------------------------------------------
-- DEVICE ADDED
-------------------------------------------------

local function device_added(driver, device)
  log.info(string.format("%s added.", device.label))
  device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({ "open", "close", "pause" },
    { visibility = { displayed = false } }))
  tuya_utils.emit_event_if_latest_state_missing(device, "main", capabilities.windowShadeLevel,
    capabilities.windowShadeLevel.shadeLevel.NAME, capabilities.windowShadeLevel.shadeLevel(0))
  tuya_utils.emit_event_if_latest_state_missing(device, "main", capabilities.windowShade,
    capabilities.windowShade.windowShade.NAME, capabilities.windowShade.windowShade.closed())
  device:emit_event(capabilities.windowShadePreset.supportedCommands({ "presetPosition", "setPresetPosition" },
    { visibility = { displayed = false } }))
  tuya_utils.emit_event_if_latest_state_missing(device, "main", capabilities.windowShadePreset,
    capabilities.windowShadePreset.position.NAME, PRESET_LEVEL)
end

-------------------------------------------------
-- DEVICE INIT
-------------------------------------------------

local function device_init(driver, device)
  log.info(string.format("%s init.", device.label))
  if device:supports_capability_by_id(capabilities.windowShadePreset.ID) and device:get_latest_state("main", capabilities.windowShadePreset.ID, capabilities.windowShadePreset.position.NAME) == nil then
    device:emit_event(capabilities.windowShadePreset.supportedCommands({ "presetPosition", "setPresetPosition" },
      { visibility = { displayed = false } }))
    local preset_position = device:get_field(PRESET_LEVEL_KEY) or PRESET_LEVEL
    device:emit_event(capabilities.windowShadePreset.position(preset_position, { visibility = { displayed = false } }))
    device:set_field(PRESET_LEVEL_KEY, preset_position, { persist = true })
  end
end

-------------------------------------------------
-- DEVICE CONFIGURED
-------------------------------------------------

local function do_configure(driver, device)
  log.info(string.format("%s configured.", device.label))
  tuya_utils.send_magic_spell(device)
  device:send(Basic.attributes.ApplicationVersion:configure_reporting(device, 30, 300, 1))
  device:send(device_management.build_bind_request(device, Basic.ID, driver.environment_info.hub_zigbee_eui))
end

-------------------------------------------------
-- INFO CHANGED
-------------------------------------------------

local function info_changed(driver, device)
  log.info(string.format("%s info changed.", device.label))

  -------------------------------------------------
  -- DIRECTION
  -------------------------------------------------

  local old_direction = device:get_field("current_direction")
  local new_direction = device.preferences.reverseDirection

  if old_direction ~= new_direction then
    log.info(string.format("Direction changed %s -> %s", tostring(old_direction), tostring(new_direction)))
    local dp_value = new_direction == "back" and 1 or 0
    tuya_utils.write_enum_dp(device, 5, dp_value)
    device:set_field("current_direction", new_direction)
  end

  -------------------------------------------------
  -- CALIBRATION
  -------------------------------------------------

  local calibration = device.preferences.calibrationAction

  if not calibration or calibration == "none" then
    return
  end

  local calibration_map = {
    up = 0,
    down = 1,
    up_delete = 2,
    down_delete = 3,
    remove_top_bottom = 4
  }

  local dp_value = calibration_map[calibration]

  if dp_value == nil then
    return
  end

  log.info(string.format("Calibration action=%s dp16=%d", calibration, dp_value))
  tuya_utils.write_enum_dp(device, 16, dp_value)
end

-------------------------------------------------
-- TUYA EF00 HANDLER
-------------------------------------------------

local function tuya_cluster_handler(driver, device, zb_rx)
  log.info("=== CURTAIN EF00 MESSAGE ===")
  local raw = nil

  if zb_rx.body and zb_rx.body.zcl_body then
    raw = zb_rx.body.zcl_body.body_bytes
  end

  if not raw then
    return
  end

  local parsed = tuya_protocol.parse(raw)
  handlers.handle_dp(device, parsed)
end

-------------------------------------------------
-- DRIVER TEMPLATE
-------------------------------------------------

local nova_digital_driver_template = {
  NAME = "nova-digital-drive",
  health_check = false,
  supported_capabilities = {
    capabilities.refresh,
    capabilities.battery,
    capabilities.windowShade,
    capabilities.windowShadeLevel,
    capabilities.windowShadePreset
  },
  capability_handlers = {
    [capabilities.windowShade.ID] = {
      [capabilities.windowShade.commands.open.NAME] = commands.open,
      [capabilities.windowShade.commands.pause.NAME] = commands.pause,
      [capabilities.windowShade.commands.close.NAME] = commands.close
    },
    [capabilities.windowShadeLevel.ID] = {
      [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = commands.set_level
    },
    [capabilities.windowShadePreset.ID] = {
      [capabilities.windowShadePreset.commands.presetPosition.NAME] = commands.preset,
      [capabilities.windowShadePreset.commands.setPresetPosition.NAME] = window_shade_preset_defaults
          .set_preset_position_cmd
    }
  },
  zigbee_handlers = {
    cluster = {
      [tuya_utils.TUYA_PRIVATE_CLUSTER] = {
        [tuya_utils.TUYA_PRIVATE_CMD_REPORT] = tuya_cluster_handler,
        [tuya_utils.TUYA_PRIVATE_CMD_RESPONSE] = tuya_cluster_handler
      }
    }
  },
  lifecycle_handlers = {
    added = device_added,
    infoChanged = info_changed,
    doConfigure = do_configure,
    init = device_init
  },
  can_handle = handlers.can_handler
}

defaults.register_for_default_handlers(nova_digital_driver_template, nova_digital_driver_template.supported_capabilities)
local nova_digital_driver = ZigbeeDriver("nova-digital-driver", nova_digital_driver_template)
nova_digital_driver:run()
