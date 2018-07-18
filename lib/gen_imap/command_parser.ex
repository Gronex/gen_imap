defmodule GenImap.CommandParser do
    
    @moduledoc """
    This module handles raw input from the client, and transforms it into matchable formats
    """

    @doc """
    Takes a raw input line as sent from the IMAP client, and translates it into
    a success tuple, containing the command if successful

    ## Examples

        iex> GenImap.CommandParser.parse("A01 NOOP")
        {:ok, "A01", :noop}

        iex> GenImap.CommandParser.parse("A01 CAPABILITY")
        {:ok, "A01", :capability}

        iex> GenImap.CommandParser.parse("A01 LOGOUT")
        {:ok, "A01", :logout}

        iex> GenImap.CommandParser.parse("A01 LOGIN \\"user\\" \\"pass\\"")
        {:ok, "A01", {:login, "user", "pass"}}

        iex> GenImap.CommandParser.parse("A01 LIST \\"\\" \\"\\"")
        {:ok, "A01", {:list, "", ""}}

        iex> GenImap.CommandParser.parse("A01 SELECT INBOX")
        {:ok, "A01", {:select, "INBOX"}}

        iex> GenImap.CommandParser.parse("A01 SELECT %")
        {:ok, "A01", {:select, "%"}}

        iex> GenImap.CommandParser.parse("A01 CREATE owatagusiam/blurdybloop")
        {:ok, "A01", {:create, "owatagusiam/blurdybloop"}}

    In case of errors an error tuple is returned

        iex> GenImap.CommandParser.parse("A01 LOGIN \\"user\\" \\"pass\\" \\"bla\\"")
        {:error, "A01", {:login, "Argument missmatch"}}

        iex> GenImap.CommandParser.parse("A01 LOGIN \\"user\\"")
        {:error, "A01", {:login, "Argument missmatch"}}

        iex> GenImap.CommandParser.parse("A01 ERROR")
        {:error, "A01", "Unknown Command"}
    
    """
    def parse(command) do
        command
        |> String.trim()
        |> String.split()
        |> do_parse()
    end

    defp do_parse([tag, "NOOP"]), do: {:ok, tag, :noop}
    defp do_parse([tag, "CAPABILITY"]), do: {:ok, tag, :capability}
    defp do_parse([tag, "LOGOUT"]), do: {:ok, tag, :logout}
    defp do_parse([tag, "LOGIN" | args]) do
        case parse_args(args) do
            [username, password] ->
                {:ok, tag, {:login, username, password}}
            _ -> arg_miss_match(tag, :login)
        end
    end

    defp do_parse([tag, "LIST" | args]) do
        case parse_args(args) do
            [ref, mbox] ->
                {:ok, tag, {:list, ref, mbox}}
            _ -> arg_miss_match(tag, :list)
        end
    end

    defp do_parse([tag, "SELECT" | args]) do
        case parse_args(args) do
            [mbox] ->
                {:ok, tag, {:select, mbox}}
            _ -> arg_miss_match(tag, :select)
        end
    end

    defp do_parse([tag, "CREATE" | args]) do
        case parse_args(args) do
            [mbox] ->
                {:ok, tag, {:create, mbox}}
            _ -> arg_miss_match(tag, :create)
        end
    end

    defp do_parse([tag, "SEARCH" | args]) do
        # TODO: parse search terms
        {:ok, tag, {:search, parse_args(args)}}
    end

    defp do_parse([tag, "FETCH" | args]) do
        case parse_args(args) do
            [uid_range | rest] -> 
                {:ok, tag, {:fetch, uid_range, rest |> Enum.join(" ")}}
                _ -> arg_miss_match(tag, :fetch)
        end
    end

    defp do_parse([tag|_cmd]), do: {:error, tag, "Unknown Command"}
    defp do_parse(_), do: {:error, "Unknown Command"}

    defp arg_miss_match(tag, cmd) do
        {:error, tag, {cmd, "Argument missmatch"}}
    end


    @doc """
    takes a list of arguments seperated by space, 
    and combines them into a list of arguments, grouped properly, 
    according to the " and similar

    ## Examples

        iex> GenImap.CommandParser.parse_args([])
        []

        iex> GenImap.CommandParser.parse_args(["test", "test2"])
        ["test", "test2"]

        iex> GenImap.CommandParser.parse_args(["\\"test", "test2\\""])
        ["test test2"]

        iex> GenImap.CommandParser.parse_args(["\\"test", "other", "words", "test2\\""])
        ["test other words test2"]

        iex> GenImap.CommandParser.parse_args(["\\"test", "other", "words", "test2\\"", "rest"])
        ["test other words test2", "rest"]

    """
    def parse_args(args) when is_list(args) do
        do_parse_args(args)
    end

    defp do_parse_args([]), do: []
    defp do_parse_args(["\"" <> word | words]) do
        {arg, rest} = [word | words]
            |> Enum.split_while(fn w -> not String.ends_with?(w, "\"") end)

        {word, tail} = case rest do
            [] -> [word | arg]
            [final | tail] -> {arg ++ [ String.trim(final, "\"") ], tail}
        end
        
        word = word
        |> Enum.join(" ")

        [word | do_parse_args(tail)]
    end
    defp do_parse_args([word | words]) do
        [word | do_parse_args(words)]
    end
end