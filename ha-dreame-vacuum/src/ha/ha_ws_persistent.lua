local cosock = require "cosock"
local socket = cosock.socket
local capabilities = require "st.capabilities"

local ha_ws = require "ha.ha_ws"

local M = {}

local connection_generation = 0
local reconnect_delay = 5

local function wait_before_reconnect()
  print("Reconectando em", reconnect_delay, "s")
  socket.sleep(reconnect_delay)

  reconnect_delay = math.min(reconnect_delay * 2, 60)
end

local function should_process_entity(entity_id, config)
  return entity_id == config.vacuum_entity_id
      or entity_id == config.cleaning_mode_entity_id
      or entity_id == config.water_volume_entity_id
end

local function start_ping_loop(client, my_generation)
  cosock.spawn(function()
    while true do
      if my_generation ~= connection_generation then
        print("Ping loop antigo encerrado")
        return
      end

      socket.sleep(30)

      if my_generation ~= connection_generation then
        print("Ping loop antigo encerrado")
        return
      end

      local ok, err = ha_ws.send_json(client, {
        id = os.time(),
        type = "ping"
      })

      if not ok then
        print("Erro enviando ping HA:", err)
        break
      end

      print("Ping enviado ao HA")
    end
  end, "ha-ws-ping")
end

function M.start(device, config, on_vacuum_state_changed)
  cosock.spawn(function()
    print("======================================")
    print("HA WebSocket persistente iniciando")
    print("======================================")

    while true do
      local ok, err = pcall(function()
        connection_generation = connection_generation + 1
        local my_generation = connection_generation

        print("Conectando WebSocket persistente no HA...")

        local client, auth_err = ha_ws.connect_and_auth(
          config.host,
          config.port,
          config.token
        )

        if not client then
          print("Erro conectando WebSocket persistente:", auth_err)
          wait_before_reconnect()
          return
        end

        device:set_field("ha_ws_connected", true, { persist = false })

        device:emit_event(
          capabilities.healthCheck.healthStatus("online")
        )

        print("WebSocket persistente autenticado")

        reconnect_delay = 5

        local subscribe_payload = {
          id = 100,
          type = "subscribe_events",
          event_type = "state_changed"
        }

        local subscribe_ok, subscribe_err = ha_ws.send_json(
          client,
          subscribe_payload
        )

        if not subscribe_ok then
          print("Erro ao assinar state_changed:", subscribe_err)

          device:set_field("ha_ws_connected", false, { persist = false })

          device:emit_event(
            capabilities.healthCheck.healthStatus("offline")
          )

          pcall(function()
            client:close()
          end)

          wait_before_reconnect()
          return
        end

        print("Inscrito em state_changed")

        start_ping_loop(client, my_generation)

        while true do
          if my_generation ~= connection_generation then
            print("Receive loop antigo encerrado")
            break
          end

          local frame, receive_err = ha_ws.receive_json(client)

          if not frame then
            if receive_err == "empty_frame" then
              print("Frame vazio recebido. Ignorando.")
            else
              print("Erro recebendo evento WebSocket:", receive_err)
              break
            end
          elseif frame.type == "pong" then
            print("Pong recebido do HA")
          elseif frame.type == "result" then
            print("Resultado recebido do HA:", tostring(frame.success))
          elseif frame.type == "event"
              and frame.event
              and frame.event.data
          then
            local entity_id = frame.event.data.entity_id
            local new_state = frame.event.data.new_state

            if should_process_entity(entity_id, config) then
              print("Evento recebido do HA:", entity_id)

              if new_state then
                on_vacuum_state_changed(device, entity_id, new_state)
              end
            end
          end
        end

        device:set_field("ha_ws_connected", false, { persist = false })

        device:emit_event(
          capabilities.healthCheck.healthStatus("offline")
        )

        pcall(function()
          client:close()
        end)

        print("WebSocket persistente desconectado.")
        wait_before_reconnect()
      end)

      if not ok then
        print("Erro fatal no WebSocket persistente:", err)

        device:set_field("ha_ws_connected", false, { persist = false })

        device:emit_event(
          capabilities.healthCheck.healthStatus("offline")
        )

        connection_generation = connection_generation + 1

        wait_before_reconnect()
      end
    end
  end, "ha-ws-persistent")
end

return M
