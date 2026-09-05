-module(bnana_photos_nif).
-export([pick/0]).
-on_load(init/0).

init() ->
    case erlang:load_nif("bnana_photos_nif", 0) of
        ok -> ok;
        {error, _} -> ok
    end.

pick() ->
    erlang:nif_error(nif_not_loaded).
