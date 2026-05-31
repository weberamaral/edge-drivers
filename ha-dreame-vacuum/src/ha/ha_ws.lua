local socket = require "cosock.socket"
local json = require "st.json"
local ws = require "ha.ws"

local ha_ws = {}

local request_id = 1

local function next_id()
  request_id = request_id + 1
  return request_id
end

local function read_headers(sock)
  local status_line, status_err = sock:receive("*l")

  if not status_line then
    return nil, status_err
  end

  print("Status WebSocket:", status_line)

  while true do
    local line, line_err = sock:receive("*l")

    if line then
      print("Header:", line)

      if line == "" then
        break
      end
    else
      return nil, line_err
    end
  end

  return status_line
end

function ha_ws.connect_and_auth(host, port, token)
  local client = socket.tcp()
  client:settimeout(20)

  local ok, err = client:connect(host, port)

  if not ok then
    return nil, err
  end

  local request =
      "GET /api/websocket HTTP/1.1\r\n" ..
      "Host: " .. host .. ":" .. port .. "\r\n" ..
      "Upgrade: websocket\r\n" ..
      "Connection: Upgrade\r\n" ..
      "Sec-WebSocket-Version: 13\r\n" ..
      "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"

  client:send(request)

  local status_line, header_err = read_headers(client)

  if not status_line or not string.find(status_line, "101") then
    client:close()
    return nil, header_err or status_line
  end

  print("WebSocket Upgrade OK")

  local frame, frame_err = ws.read_frame(client)

  if not frame then
    client:close()
    return nil, frame_err
  end

  print("Frame inicial recebido:", frame.payload)

  local auth_payload = '{"type":"auth","access_token":"' .. token .. '"}'

  local send_ok, send_err = ws.send_text(client, auth_payload)

  if not send_ok then
    client:close()
    return nil, send_err
  end

  local auth_frame, auth_err = ws.read_frame(client)

  if not auth_frame then
    client:close()
    return nil, auth_err
  end

  print("Frame auth recebido:", auth_frame.payload)

  if not string.find(auth_frame.payload, "auth_ok") then
    client:close()
    return nil, "auth_failed"
  end

  print("SUCESSO: autenticado no Home Assistant")

  return client, nil
end

function ha_ws.send_json(client, payload)
  local encoded = json.encode(payload)
  return ws.send_text(client, encoded)
end

function ha_ws.receive_json(client)
  local frame, err = ws.read_frame(client)

  if not frame then
    return nil, err
  end

  local payload = frame.payload

  if not payload or payload == "" then
    return nil, "empty_frame"
  end

  local ok, decoded = pcall(json.decode, payload)

  if not ok then
    print("Erro decodificando frame WebSocket:")
    print(payload)
    return nil, "json_decode_failed"
  end

  return decoded, nil
end

function ha_ws.connect_auth_and_get_states(host, port, token)
  local client, err = ha_ws.connect_and_auth(host, port, token)

  if not client then
    return nil, err
  end

  local id = next_id()
  local get_states_payload = '{"id":' .. id .. ',"type":"get_states"}'

  print("Enviando get_states")

  local send_ok, send_err = ws.send_text(client, get_states_payload)

  if not send_ok then
    client:close()
    return nil, send_err
  end

  local states_frame, states_err = ws.read_frame(client)

  if not states_frame then
    client:close()
    return nil, states_err
  end

  local decoded = json.decode(states_frame.payload)

  client:close()

  if not decoded or not decoded.success then
    return nil, "get_states_failed"
  end

  return decoded.result, nil
end

function ha_ws.call_service(host, port, token, domain, service, service_data)
  local client, err = ha_ws.connect_and_auth(host, port, token)

  if not client then
    return false, err
  end

  local id = next_id()

  local payload_table = {
    id = id,
    type = "call_service",
    domain = domain,
    service = service,
    service_data = service_data or {}
  }

  local payload = json.encode(payload_table)

  print("Enviando call_service:")
  print(payload)

  local send_ok, send_err = ws.send_text(client, payload)

  if not send_ok then
    client:close()
    return false, send_err
  end

  local response_frame, response_err = ws.read_frame(client)

  if not response_frame then
    client:close()
    return false, response_err
  end

  print("Resposta call_service:")
  print(response_frame.payload)

  local decoded = json.decode(response_frame.payload)

  client:close()

  if decoded and decoded.success == true then
    print("SUCESSO: call_service executado")
    return true, nil
  end

  return false, "call_service_failed"
end

return ha_ws
