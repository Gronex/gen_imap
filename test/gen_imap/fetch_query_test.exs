defmodule GenImap.FetchQueryTest do
    use ExUnit.Case
    doctest GenImap.FetchQuery, async: true

    alias GenImap.FetchQuery

    test "Full macro expands" do
        unwrapped = [
            "BODY",
            "ENVELOPE",
            "FLAGS",
            "INTERNALDATE",
            "RFC822.SIZE",
        ]
        
        assert unwrapped == FetchQuery.expand_macros(["FULL"])
    end

    test "All macro expands" do
        unwrapped = [
            "ENVELOPE",
            "FLAGS",
            "INTERNALDATE",
            "RFC822.SIZE",
        ]
        
        assert unwrapped == FetchQuery.expand_macros(["ALL"])
    end

    test "Fast macro expands" do
        unwrapped = [
            "FLAGS",
            "INTERNALDATE",
            "RFC822.SIZE",
        ]
        
        assert unwrapped == FetchQuery.expand_macros(["FAST"])
    end

    test "Query can have mixed macroes, and query params" do
        expected = [
            "FLAGS",
            "INTERNALDATE",
            "RFC822.SIZE",
            "BODY",
            "WHATEVER"
        ]
        
        assert expected == FetchQuery.expand_macros(["FAST", "BODY", "WHATEVER"])
    end
end