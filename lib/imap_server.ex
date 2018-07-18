defmodule ImapServer do
    require Logger

    @default_opts %{
       port: 1430,
       server_name: "IMAP4rev1 GenImap server",
       tls_enabeled: false
    }

    def start_link(opts \\ []) do
        opts = %{
            port: port,
            server_name: server_name
        } = Enum.into(opts, @default_opts)
        
        Logger.info("Starting #{server_name}, listening on port #{port}")
        {:ok, _} = :ranch.start_listener(
            __MODULE__, 
            100,
            :ranch_tcp, 
            [port: port], 
            GenImap.ImapProtocol, 
            opts)
    end
end