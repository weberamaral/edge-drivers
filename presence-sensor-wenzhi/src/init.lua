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

local capabilities = require "st.capabilities"
local defaults = require "st.zigbee.defaults"
local ZigbeeDriver = require "st.zigbee"
local device_management = require "st.zigbee.device_management"
local clusters = require "st.zigbee.zcl.clusters"

local log = require "log"

local tuya_utils = require "tuya.tuya_utils"
local tuya_protocol = require "tuya.tuya_protocol"
local handler = require "handler"

local Basic = clusters.Basic

-------------------------------------------------
-- DEVICE ADDED
-------------------------------------------------

local function device_added(driver, device)
  log.info(string.format("Presence sensor added: %s", device.label))
  device:emit_event(capabilities.presenceSensor.presence.not_present())
  device:emit_event(capabilities.illuminanceMeasurement.illuminance(0))
end

-------------------------------------------------
-- DO CONFIGURE
-------------------------------------------------

local function do_configure(driver, device)
  log.info(string.format("Configuring presence sensor: %s", device.label))
  tuya_utils.send_magic_spell(device)
  device:send(Basic.attributes.ApplicationVersion:configure_reporting(device, 30, 300, 1))
  device:send(device_management.build_bind_request(device, Basic.ID, driver.environment_info.hub_zigbee_eui))
end

-------------------------------------------------
-- INFO CHANGED
-------------------------------------------------

local function info_changed(driver, device, event, args)
  log.info(string.format("Device preferences info changed: %s", device.label))

  -------------------------------------------------
  -- FADING TIME
  -------------------------------------------------

  local old_fading = device:get_field("last_fading_time")
  local new_fading = device.preferences.fadingTime

  if new_fading and old_fading ~= new_fading then
    log.info(string.format("NEW FADING TIME: %s", new_fading))
    tuya_utils.write_number_dp(device, 106, new_fading)
    device:set_field("last_fading_time", new_fading)
  end

  -------------------------------------------------
  -- FAR DETECTION
  -------------------------------------------------

  local old_far = device:get_field("last_far_detection")
  local new_far = device.preferences.farDetection

  if new_far and old_far ~= new_far then
    log.info(string.format("NEW FAR DETECTION: %s", new_far))
    tuya_utils.write_number_dp(device, 4, new_far)
    device:set_field("last_far_detection", new_far)
  end

  -------------------------------------------------
  -- PRESENCE SENSITIVITY
  -------------------------------------------------

  local old_presence_sensitivity = device:get_field("last_presence_sensitivity")
  local new_presence_sensitivity = device.preferences.presenceSensitivity

  if new_presence_sensitivity and old_presence_sensitivity ~= new_presence_sensitivity then
    log.info(string.format("NEW PRESENCE SENSITIVITY: %s", new_presence_sensitivity))
    tuya_utils.write_number_dp(device, 102, new_presence_sensitivity)
    device:set_field("last_presence_sensitivity", new_presence_sensitivity)
  end

  -------------------------------------------------
  -- SENSITIVITY
  -------------------------------------------------

  local old_sensitivity = device:get_field("last_sensitivity")
  local new_sensitivity = device.preferences.sensitivity

  if new_sensitivity and old_sensitivity ~= new_sensitivity then
    log.info(string.format("NEW SENSITIVITY: %s", new_sensitivity))
    tuya_utils.write_number_dp(device, 2, new_sensitivity)
    device:set_field("last_sensitivity", new_sensitivity)
  end

  -------------------------------------------------
  -- NEAR DETECTION
  -------------------------------------------------

  local old_near = device:get_field("last_near_detection")
  local new_near = device.preferences.nearDetection

  if new_near and old_near ~= new_near then
    log.info(string.format("NEW NEAR DETECTION: %s", new_near))
    tuya_utils.write_number_dp(device, 3, new_near)
    device:set_field("last_near_detection", new_near)
  end

  -------------------------------------------------
  -- DETECTION DELAY
  -------------------------------------------------

  local old_detection_delay = device:get_field("last_detection_delay")
  local new_detection_delay = device.preferences.detectionDelay

  if new_detection_delay and old_detection_delay ~= new_detection_delay then
    log.info(string.format("NEW DETECTION DELAY: %s", new_detection_delay))
    tuya_utils.write_number_dp(device, 105, new_detection_delay)
    device:set_field("last_detection_delay", new_detection_delay)
  end
end

-------------------------------------------------
-- TUYA EF00 HANDLER
-------------------------------------------------

local function tuya_cluster_handler(driver, device, zb_rx)
  log.info("=== TUYA EF00 MESSAGE ===")
  local raw = nil

  if zb_rx.body and zb_rx.body.zcl_body then
    raw = zb_rx.body.zcl_body.body_bytes
  end

  if not raw then
    log.warn("No raw body")
    return
  end

  local parsed = tuya_protocol.parse(raw)
  handler.handle_dp(device, parsed)
  log.info("========================")
end

-------------------------------------------------
-- DRIVER TEMPLATE
-------------------------------------------------

local wenzhi_driver_template = {
  NAME = "wenzhi-driver",
  health_check = false,
  supported_capabilities = {
    capabilities.refresh,
    capabilities.presenceSensor,
    capabilities.illuminanceMeasurement
  },
  zigbee_handlers = {
    cluster = {
      [tuya_utils.TUYA_PRIVATE_CLUSTER] = {
        [tuya_utils.TUYA_PRIVATE_CMD_REPORT] = tuya_cluster_handler,
        [tuya_utils.TUYA_PRIVATE_CMD_RESPONSE] = tuya_cluster_handler,
      }
    }
  },
  lifecycle_handlers = {
    added = device_added,
    doConfigure = do_configure,
    infoChanged = info_changed
  },
  can_handle = handler.can_handle
}

defaults.register_for_default_handlers(wenzhi_driver_template, wenzhi_driver_template.supported_capabilities)
local wenzhi_driver = ZigbeeDriver("wenzhi-driver", wenzhi_driver_template)
wenzhi_driver:run()
