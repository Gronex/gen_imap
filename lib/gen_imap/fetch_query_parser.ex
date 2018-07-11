defmodule GenImap.FetchQueryParser do
    import NimbleParsec

    def group([token | rest]) do
        {token, rest}
    end

    whitespace =
        ascii_char([?\s])
        |> optional()
        |> ignore()
    
    token = utf8_string([?a..?z, ?A..?Z, ?0..?9, ?.], min: 1)

    token_group = 
        token
        |> ignore(ascii_char([?[]))
        |> times(parsec(:parse) |> concat(whitespace), min: 1)
        |> ignore(ascii_char([?]]))
        |> wrap()
        |> map({:group, []})
    
        
        
    defparsec :list, 
        ignore(ascii_char([?(]))
        |> times(parsec(:parse) |> concat(whitespace), min: 1)
        |> ignore(ascii_char([?)]))
        |> wrap()

    defparsec :parse, 
        choice([
            token_group,
            token,
            parsec(:list)
        ])
end