defmodule GenImapBehaviour do
    @type state :: any

    @callback login(username :: String.t, password :: String.t, state :: state) :: {:ok, state} | {:error, String.t} | {:invalid, state}
    @callback logout(state :: any) :: {:ok, state}
    
    @optional_callbacks logout: 1
end