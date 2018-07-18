defmodule GenImap.ImapProtocol do
    @behaviour :ranch_protocol

    alias __MODULE__

    require Logger

    @type state :: any
    @type result :: {:ok, state} | {:error, state} | {:invalid, state}

    @callback init(opts :: map) :: {:ok, state} | {:error, any}
    @callback login(username :: String.t, password :: String.t, state) :: result
    @callback logout(state :: state) :: {:ok, state}
    @callback handle_fetch(query :: list, uid_range :: [min: integer, max: integer] | [min: integer] | [max: integer] | integer, state) :: result
    
    @optional_callbacks logout: 1


    defstruct [
        callback_module: nil,
        state: nil,
        server_name: nil
    ]

    @capabilities [
        "CAPABILITY", 
        "IMAP4rev1", 
        #"IDLE", 
        #"STARTTLS",
        "LOGINDISABLED"
      ]

    @impl true
    def start_link(ref, socket, transport, opts) do
        Logger.info("Client connected. #{inspect(opts)}")
        pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])
        {:ok, pid}
    end

    def init(ref, socket, transport, %{server_name: server_name, callback_module: callback_module} = opts) do
        
        case callback_module.init(opts) do
            {:ok, init_state} ->
                :ok = :ranch.accept_ack(ref)
                transport.send(socket, "* OK #{server_name} Ready\r\n")
        
                state = %ImapProtocol{
                    callback_module: callback_module,
                    server_name: server_name,
                    state: init_state
                }
        
                Logger.info("Ready for messages.")
        
                loop(socket, transport, state)
            
            _ ->
                transport.send("* Error occured\r\n")
                :ok = transport.close()
        end
    end

    defp loop(socket, transport, state) do
        case transport.recv(socket, 0, 5000) do
            {:ok, data} ->
                with :ok = Logger.debug("Recieved: #{data |> String.trim}"),
                    {:ok, tag, command} <- GenImap.CommandParser.parse(data),
                    {:ok, responses, state} <- execute_command(command, state, tag) do
                        :ok = respond(transport, socket, responses)
                        loop(socket, transport, state)
                else
                    {:close, _state} ->
                        Logger.info("Closing connection.")
                        :ok = transport.close(socket)        

                    {:error, tag, {_cmd, reason}} -> 
                        transport.send(socket, "#{tag} BAD #{reason}\r\n")
                        loop(socket, transport, state)

                    {:error, reason} ->
                        transport.send(socket, "BAD #{reason}\r\n")
                        loop(socket, transport, state)
                    
                    {:close, responses, _state} ->
                        :ok = respond(transport, socket, responses)
                        :ok = transport.close(socket)

                    err ->
                        transport.send(socket, "BAD Internal error.\r\n")
                        Logger.error("Unknown error #{inspect(err)}")
                        :ok = transport.close(socket)
                end


            {:error, :closed} -> 
                Logger.warn("Connection closed unexpectedly.")
                :ok = transport.close(socket)

            {:error, :timeout} ->
                Logger.warn("No message within alotted time. Closing connection.")
                :ok = transport.close(socket)
            
            _ -> 
                :ok = transport.close(socket)
        end
    end

    defp respond(transport, socket, responses) do
        msg = responses
        |> Enum.map(fn (m) -> m <> "\r\n" end)
        |> Enum.join("")
        
        Logger.debug("Sending: \r\n#{msg}")
        transport.send(socket, msg)
        :ok
    end

    defp execute_command(:noop, state, tag) do
        # TODO: Trigger sending status
        
        {:ok, ["#{tag} OK"], state}
      end

      
      defp execute_command({:login, username, password}, %ImapProtocol{callback_module: callback_module, state: inner_state} = state, tag) do
        case callback_module.login(username, password, inner_state) do
            {:ok, inner_state} ->
                {:ok, ["#{tag} OK user logged in"], %{state | state: inner_state}}
            
            {:invalid, inner_state} ->
                {:ok, ["#{tag} NO invalid username or password"], %{state | state: inner_state}}

            {:error, inner_state} ->
                {:ok, ["#{tag} BAD Error occured"], %ImapProtocol{state | state: inner_state}}
        end
      end

      defp execute_command(:logout, %ImapProtocol{callback_module: callback_module, state: inner_state} = state, tag) do
        state = cond do
            function_exported?(callback_module, :logout, 1) ->
                {:ok, inner_state} = callback_module.logout(inner_state)
                %ImapProtocol{state | state: inner_state}
            
            true ->
                state
                
        end

        {:close, ["BYE", "#{tag} OK"], state}
      end
    
      defp execute_command({:list, _ref, _mbox}, state, tag) do
        {:ok, ["#{tag} OK"], state}
      end
    
      defp execute_command({:select, _mbox}, state, tag) do
        response = [
            "* 1 EXISTS",
            "* OK [UNSEEN 12]",
            "* FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft)",
            "* OK [PERMANENTFLAGS (\\Deleted \\Seen \\*)]",
            "#{tag} OK"
        ]
    
        {:ok, response, state}
      end
    
      defp execute_command(:capability, state, tag) do
        capabilities = 
          @capabilities
          |> Enum.join(" ")

        response = [
            "* #{capabilities}",
            "#{tag} OK"
        ]

        {:ok, response, state}
      end
    
      defp execute_command({:search, _args}, state, tag) do
        response = [
            "* SEARCH 1 2 3 4 89 99",
            "#{tag} OK"
        ]

        {:ok, response, state}
      end
    
      defp execute_command({:fetch, uid_range, args}, %ImapProtocol{callback_module: callback_module, state: inner_state} = state, tag) do    
        with {:ok, [query], _rest, _, _, _} <- GenImap.FetchQueryParser.parse(args),
            {:ok, _results, inner_state} <- callback_module.handle_fetch(query, uid_range, inner_state) do
                # TODO: translate results
                {:ok, ["#{tag} OK"], %ImapProtocol{state | state: inner_state}}
        else
          _ -> 
            {:ok, ["#{tag} BAD Unsupported query"], state}
        end
      end
    
      defp execute_command(command, state, tag) do
        Logger.warn("Unsupported command #{inspect(command)}")
        {:ok, ["#{tag} BAD Unsupported command"], state}
      end
end