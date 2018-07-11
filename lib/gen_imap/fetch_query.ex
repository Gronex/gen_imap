defmodule GenImap.FetchQuery do

    def expand_macros([]), do: []
    def expand_macros(query) when is_list(query) do
        query
        |> Enum.flat_map(&do_expand_macro/1)
    end
    
    defp do_expand_macro("FAST") do
        [
            "FLAGS",
            "INTERNALDATE",
            "RFC822.SIZE",
        ]
    end

    defp do_expand_macro("ALL") do
        ["ENVELOPE" | do_expand_macro("FAST")]
    end

    defp do_expand_macro("FULL") do
        ["BODY" | do_expand_macro("ALL")]
    end

    defp do_expand_macro(query), do: [query]
end