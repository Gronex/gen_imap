defmodule GenImap.Example.Protocol do
    @behaviour GenImap.ImapProtocol
    
    require Logger

    def start() do
        ImapServer.start_link([callback_module: __MODULE__])
    end

    @impl true
    def init(_opts) do
       {:ok, %{}}
    end

    @impl true
    def login(username, password, state) do
        if username == "test" and password == "test" do
            {:ok, state |> Map.put("user", username)}
        else
            {:invalid, state}
        end
    end

    @impl true
    def handle_fetch(query, uid_range, state) do
        Logger.info("Range: #{uid_range}")
        Logger.info("query: #{inspect(query)}")
        {:ok, [], state}
    end

    @impl true
    def logout(%{"user" => user} = state) do
        Logger.info("Logging #{user} out")
        {:ok, state}
    end

    @impl true
    def logout(state) do
        Logger.info("User not logged in")
        {:ok, state}
    end
end