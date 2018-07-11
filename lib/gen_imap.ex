defmodule GenImap do
  @moduledoc """
  Documentation for GenImap.
  """
  require Logger

  alias GenImap.CommandParser

  @capabilities [
    "CAPABILITY", 
    "IMAP4rev1", 
    #"IDLE", 
    #"STARTTLS",
    "LOGINDISABLED"
  ]

  @servername "IMAP4rev1 GenImap server"

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])

    Logger.info("#{@servername} started on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Imap.TaskSupervisor, fn -> serve(%{socket: client, state: :init}) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp serve(%{socket: socket, state: :init} = state) do
    socket
    |> write_line("* OK #{@servername} Ready")

    serve(%{state | state: :listen})
  end

  defp serve(%{state: :closed}) do
    Logger.info("Connection closed.")
  end

  defp serve(%{socket: socket} = state) do
    with {:ok, data} <- read_line(socket),
      {:ok, tag, command} <- CommandParser.parse(data),
      {:ok, state} <- execute_command(command, state, tag) do
        serve(state)

    else
      {:error, tag, {_cmd, reason}} ->
        socket
        |> error_command(reason, tag)
        
        serve(state)

      {:error, tag, reason} ->
        socket
        |> error_command(reason, tag)

        serve(state)

      {:error, reason} when is_binary(reason)->
        socket
        |> error_command(reason)

        serve(state)

      err -> 
        Logger.error("Unknown error #{inspect(err)}")
        %{state | state: :closed}
        |> serve()
    end
  end

  defp read_line(socket) do
    data = :gen_tcp.recv(socket, 0)
    Logger.debug("Recieved: #{inspect(data)}")
    data
  end

  
  defp write_line(socket, line) when is_binary(line) do
    line = String.trim(line)
    Logger.info("Sending: '#{line}'")
    :gen_tcp.send(socket, line <> "\r\n")
    socket
  end
  
  defp send_data(socket, data) when is_binary(data) do
    socket
    |> write_line("* #{data}")
  end

  defp end_command_ok(socket, tag, data \\ "") do
    socket
    |> write_line("#{tag} OK #{data}")
  end
  
  defp end_command_invalid(socket, tag, reason) do
    socket
    |> write_line("#{tag} NO #{reason}")
  end

  defp error_command(socket, reason, tag \\ "") do
    socket 
    |> write_line("#{tag} BAD #{reason}")
  end

  defp execute_command(:noop, %{socket: socket} = state, tag) do
    # TODO: Trigger sending status
    socket
      |> end_command_ok(tag)

    {:ok, state}
  end

  defp execute_command(:logout, %{socket: socket} = state, tag) do

    # TODO: call logout implementation if implemented

    socket
      |> send_data("BYE")
      |> end_command_ok(tag)
      |> :gen_tcp.close()

    {:ok, %{state | state: :closed}}
  end

  defp execute_command({:list, _ref, _mbox}, %{socket: socket} = state, tag) do
    socket
    |> end_command_ok(tag)

    {:ok, state}
  end

  defp execute_command({:select, _mbox}, %{socket: socket} = state, tag) do
    socket
    |> send_data("1 EXISTS")
    |> send_data("OK [UNSEEN 12]")
    |> send_data("FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft)")
    |> send_data("OK [PERMANENTFLAGS (\\Deleted \\Seen \\*)]")
    |> end_command_ok(tag)

    {:ok, state}
  end

  defp execute_command(:capability, %{socket: socket} = state, tag) do
    capabilities = 
      @capabilities
      |> Enum.join(" ")
    
    socket
    |> send_data(capabilities)
    |> end_command_ok(tag)

    {:ok, state}
  end

  defp execute_command({:search, _args}, %{socket: socket} = state, tag) do
    socket
    |> send_data("SEARCH 89")
    |> end_command_ok(tag)

    {:ok, state}
  end

  defp execute_command({:fetch, _uid_range, _args}, %{socket: socket} = state, tag) do
    socket
    |> send_data("89 FETCH (UID 89 FLAGS (\\Seen))")
    |> end_command_ok(tag)

    {:ok, state}
  end

  defp execute_command({:login, username, password}, %{socket: socket} = state, tag) do
    # TODO: Login
    if username == "test" and password == "test" do
      socket
      |> end_command_ok(tag)

      {:ok, state}
    else
      {:error, tag, "Invalid Username or Password", state}
    end

  end

  defp execute_command(command, state, tag) do
    Logger.warn("Unsupported command #{inspect(command)}")
    {:error, tag, "Unsupported command", state}
  end
end
