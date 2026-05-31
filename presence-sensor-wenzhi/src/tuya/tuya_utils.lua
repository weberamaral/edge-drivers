---@diagnostic disable: undefined-global
local device_lib = require "st.device"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local zcl_messages = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local data_types = require "st.zigbee.data_types"
local zb_const = require "st.zigbee.constants"
local generic_body = require "st.zigbee.generic_body"
local zcl_header = require "st.zigbee.zcl"
local read_attribute = require "st.zigbee.zcl.global_commands.read_attribute"

local TUYA_PRIVATE_CLUSTER = 0xEF00
local TUYA_PRIVATE_CMD_RESPONSE = 0x01
local TUYA_PRIVATE_CMD_REPORT = 0x02

local tuya_utils = {}

-------------------------------------------------
-- MAGIC SPELL
-------------------------------------------------

local function read_attribute_function(device, cluster_id, attr_id)
  local read_body =
      read_attribute.ReadAttribute(attr_id)

  local zclh = zcl_messages.ZclHeader({
    cmd = data_types.ZCLCommandId(
      read_attribute.ReadAttribute.ID
    )
  })

  local addrh = messages.AddressHeader(
    zb_const.HUB.ADDR,
    zb_const.HUB.ENDPOINT,
    device:get_short_address(),
    device:get_endpoint(zcl_clusters.Basic.ID),
    zb_const.HA_PROFILE_ID,
    zcl_clusters.Basic.ID
  )

  local message_body = zcl_messages.ZclMessageBody({
    zcl_header = zclh,
    zcl_body = read_body
  })

  return messages.ZigbeeMessageTx({
    address_header = addrh,
    body = message_body
  })
end

-------------------------------------------------
-- SEND MAGIC SPELL
-------------------------------------------------

tuya_utils.send_magic_spell = function(device)
  local magic_spell = {
    0x0004,
    0x0000,
    0x0001,
    0x0005,
    0x0007,
    0xfffe
  }

  device:send(
    read_attribute_function(
      device,
      zcl_clusters.Basic.ID,
      magic_spell
    )
  )
end

-------------------------------------------------
-- WRITE TUYA DP
-------------------------------------------------

tuya_utils.write_number_dp = function(
    device,
    dp,
    value
)
  local dp_type = 0x02

  -------------------------------------------------
  -- TRANSACTION
  -------------------------------------------------

  local transaction_id = math.random(0, 65535)

  -------------------------------------------------
  -- TUYA PAYLOAD
  -------------------------------------------------

  local payload = string.char(
    math.floor(transaction_id / 256),
    transaction_id % 256,

    dp,
    dp_type,

    0x00,
    0x04,

    bit32.band(bit32.rshift(value, 24), 0xFF),
    bit32.band(bit32.rshift(value, 16), 0xFF),
    bit32.band(bit32.rshift(value, 8), 0xFF),
    bit32.band(value, 0xFF)
  )

  -------------------------------------------------
  -- ZCL HEADER
  -------------------------------------------------

  local zclh = zcl_messages.ZclHeader({
    cmd = data_types.ZCLCommandId(0x00)
  })

  zclh.frame_ctrl:set_cluster_specific()
  zclh.frame_ctrl:set_disable_default_response()

  -------------------------------------------------
  -- ADDRESS HEADER
  -------------------------------------------------

  local addrh = messages.AddressHeader(
    zb_const.HUB.ADDR,
    zb_const.HUB.ENDPOINT,
    device:get_short_address(),
    device:get_endpoint(TUYA_PRIVATE_CLUSTER),
    zb_const.HA_PROFILE_ID,
    TUYA_PRIVATE_CLUSTER
  )

  -------------------------------------------------
  -- MESSAGE BODY
  -------------------------------------------------

  local message_body =
      zcl_messages.ZclMessageBody({

        zcl_header = zclh,

        zcl_body = generic_body.GenericBody(
          payload
        )
      })

  -------------------------------------------------
  -- SEND
  -------------------------------------------------

  device:send(
    messages.ZigbeeMessageTx({
      address_header = addrh,
      body = message_body
    })
  )
end

-------------------------------------------------
-- WRITE ENUM DP
-------------------------------------------------

-------------------------------------------------
-- WRITE ENUM DP
-------------------------------------------------

tuya_utils.write_enum_dp = function(
    device,
    dp,
    value
)
  local dp_type = 0x04

  -------------------------------------------------
  -- TRANSACTION
  -------------------------------------------------

  local transaction_id = math.random(0, 65535)

  -------------------------------------------------
  -- TUYA PAYLOAD
  -------------------------------------------------

  local payload = string.char(
    math.floor(transaction_id / 256),
    transaction_id % 256,

    dp,
    dp_type,

    0x00,
    0x01,

    value
  )

  -------------------------------------------------
  -- ZCL HEADER
  -------------------------------------------------

  local zclh = zcl_messages.ZclHeader({
    cmd = data_types.ZCLCommandId(0x00)
  })

  zclh.frame_ctrl:set_cluster_specific()
  zclh.frame_ctrl:set_disable_default_response()

  -------------------------------------------------
  -- ADDRESS HEADER
  -------------------------------------------------

  local addrh = messages.AddressHeader(
    zb_const.HUB.ADDR,
    zb_const.HUB.ENDPOINT,
    device:get_short_address(),
    device:get_endpoint(TUYA_PRIVATE_CLUSTER),
    zb_const.HA_PROFILE_ID,
    TUYA_PRIVATE_CLUSTER
  )

  -------------------------------------------------
  -- MESSAGE BODY
  -------------------------------------------------

  local message_body =
      zcl_messages.ZclMessageBody({

        zcl_header = zclh,

        zcl_body = generic_body.GenericBody(
          payload
        )
      })

  -------------------------------------------------
  -- SEND
  -------------------------------------------------

  device:send(
    messages.ZigbeeMessageTx({
      address_header = addrh,
      body = message_body
    })
  )
end

-------------------------------------------------
-- CONSTANTS
-------------------------------------------------

tuya_utils.TUYA_PRIVATE_CLUSTER =
    TUYA_PRIVATE_CLUSTER

tuya_utils.TUYA_PRIVATE_CMD_RESPONSE =
    TUYA_PRIVATE_CMD_RESPONSE

tuya_utils.TUYA_PRIVATE_CMD_REPORT =
    TUYA_PRIVATE_CMD_REPORT

return tuya_utils
