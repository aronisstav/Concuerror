-module(dekker).

-export([scenarios/0]).
-export([test/0]).

scenarios() ->
    [{test, B, full} || B <- [0,1]].

-define(TABLE, table).

test() ->
    ?TABLE = ets:new(?TABLE, [public, named_table]),
    write(x,0),
    write(y,0),
    spawn(fun() -> work(1) end),
    spawn(fun() -> work(2) end),
    receive after infinity -> ok end.

work(1) ->
    case read(x) =:= 0 of
        true -> write(y,1);
        false -> ok
    end;
work(2) ->
    case read(y) =:= 0 of
        true -> write(x,1);
        false -> ok
    end.

write(Key, Value) ->
    ets:insert(?TABLE, {Key, Value}).

read(Key) ->
    [{Key, V}] = ets:lookup(?TABLE, Key),
    V.
