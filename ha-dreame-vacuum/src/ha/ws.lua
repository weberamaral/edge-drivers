local bit = require "bit32"

local ws = {}

local function bxor(a, b)
  return bit.bxor(a, b)
end

local function band(a, b)
  return bit.band(a, b)
end

local function rshift(a, b)
  return bit.rshift(a, b)
end

local function read_exact(sock, n)
  local chunks = {}
  local remaining = n

  while remaining > 0 do
    local chunk, err, partial = sock:receive(remaining)

    if chunk then
      table.insert(chunks, chunk)
      remaining = remaining - #chunk
    elseif partial and #partial > 0 then
      table.insert(chunks, partial)
      remaining = remaining - #partial
    else
      return nil, err
    end
  end

  return table.concat(chunks)
end

function ws.read_frame(sock)
  local header, err = read_exact(sock, 2)

  if not header then
    return nil, err
  end

  local b1 = string.byte(header, 1)
  local b2 = string.byte(header, 2)

  local opcode = band(b1, 0x0F)
  local masked = band(b2, 0x80) ~= 0
  local payload_len = band(b2, 0x7F)

  if payload_len == 126 then
    local ext, ext_err = read_exact(sock, 2)

    if not ext then
      return nil, ext_err
    end

    local b3 = string.byte(ext, 1)
    local b4 = string.byte(ext, 2)

    payload_len = b3 * 256 + b4
  elseif payload_len == 127 then
    local ext, ext_err = read_exact(sock, 8)

    if not ext then
      return nil, ext_err
    end

    local b1e = string.byte(ext, 1)
    local b2e = string.byte(ext, 2)
    local b3e = string.byte(ext, 3)
    local b4e = string.byte(ext, 4)
    local b5e = string.byte(ext, 5)
    local b6e = string.byte(ext, 6)
    local b7e = string.byte(ext, 7)
    local b8e = string.byte(ext, 8)

    local high =
        b1e * 16777216 +
        b2e * 65536 +
        b3e * 256 +
        b4e

    local low =
        b5e * 16777216 +
        b6e * 65536 +
        b7e * 256 +
        b8e

    if high ~= 0 then
      return nil, "Payload muito grande para esta POC"
    end

    payload_len = low
  end

  local mask_key = nil

  if masked then
    mask_key, err = read_exact(sock, 4)

    if not mask_key then
      return nil, err
    end
  end

  local payload = ""

  if payload_len > 0 then
    payload, err = read_exact(sock, payload_len)

    if not payload then
      return nil, err
    end
  end

  if masked then
    local unmasked = {}

    for i = 1, #payload do
      local payload_byte = string.byte(payload, i)
      local mask_byte = string.byte(mask_key, ((i - 1) % 4) + 1)

      unmasked[i] = string.char(bxor(payload_byte, mask_byte))
    end

    payload = table.concat(unmasked)
  end

  return {
    opcode = opcode,
    payload = payload
  }
end

function ws.send_text(sock, text)
  local payload_len = #text
  local mask_key = string.char(0x12, 0x34, 0x56, 0x78)

  local frame = {}

  table.insert(frame, string.char(0x81))

  if payload_len < 126 then
    table.insert(frame, string.char(0x80 + payload_len))
  elseif payload_len <= 65535 then
    table.insert(frame, string.char(0x80 + 126))
    table.insert(frame, string.char(rshift(payload_len, 8), band(payload_len, 0xFF)))
  else
    return nil, "Payload muito grande para esta POC"
  end

  table.insert(frame, mask_key)

  local masked_payload = {}

  for i = 1, payload_len do
    local payload_byte = string.byte(text, i)
    local mask_byte = string.byte(mask_key, ((i - 1) % 4) + 1)

    masked_payload[i] = string.char(bxor(payload_byte, mask_byte))
  end

  table.insert(frame, table.concat(masked_payload))

  return sock:send(table.concat(frame))
end

return ws
