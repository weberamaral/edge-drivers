local log = require "log"

local tuya_protocol = {}

-------------------------------------------------
-- TUYA DATATYPES
-------------------------------------------------

tuya_protocol.data_types = {
  RAW    = 0x00,
  BOOL   = 0x01,
  VALUE  = 0x02,
  STRING = 0x03,
  ENUM   = 0x04,
  BITMAP = 0x05
}

-------------------------------------------------
-- HEX DUMP
-------------------------------------------------

local function hex_dump(str)
  if not str then
    return "nil"
  end

  local hex = {}

  for i = 1, #str do
    hex[#hex + 1] =
        string.format("%02X", str:byte(i))
  end

  return table.concat(hex, " ")
end

-------------------------------------------------
-- READ UINT32
-------------------------------------------------

local function read_uint32(bytes)
  local value = 0

  for i = 1, #bytes do
    value = (value * 256) + bytes[i]
  end

  return value
end

-------------------------------------------------
-- PARSE EF00 MESSAGE
-------------------------------------------------

function tuya_protocol.parse(body)
  if not body then
    return nil
  end

  -------------------------------------------------
  -- MINIMUM LENGTH
  -------------------------------------------------

  if #body < 7 then
    return nil
  end

  -------------------------------------------------
  -- RAW LOG
  -------------------------------------------------

  log.info("RAW:")
  log.info(hex_dump(body))

  -------------------------------------------------
  -- FIELDS
  -------------------------------------------------

  local dp = body:byte(3)

  local datatype = body:byte(4)

  local data_len =
      (body:byte(5) * 256) +
      body:byte(6)

  -------------------------------------------------
  -- DATA BYTES
  -------------------------------------------------

  local data = {}

  for i = 1, data_len do
    data[i] = body:byte(6 + i)
  end

  -------------------------------------------------
  -- VALUE
  -------------------------------------------------

  local value = nil

  -------------------------------------------------
  -- BOOL
  -------------------------------------------------

  if datatype == tuya_protocol.data_types.BOOL then
    value = data[1]

    -------------------------------------------------
    -- ENUM
    -------------------------------------------------
  elseif datatype == tuya_protocol.data_types.ENUM then
    value = data[1]

    -------------------------------------------------
    -- VALUE
    -------------------------------------------------
  elseif datatype == tuya_protocol.data_types.VALUE then
    value = read_uint32(data)

    -------------------------------------------------
    -- RAW
    -------------------------------------------------
  else
    value = data
  end

  -------------------------------------------------
  -- LOGS
  -------------------------------------------------

  log.info(string.format("DP: %d", dp))
  log.info(string.format("DATATYPE: 0x%02X", datatype))
  log.info(string.format("LEN: %d", data_len))
  log.info(string.format("VALUE: %s", tostring(value)))

  -------------------------------------------------
  -- RETURN
  -------------------------------------------------

  return {
    dp = dp,
    datatype = datatype,
    length = data_len,
    value = value
  }
end

return tuya_protocol
