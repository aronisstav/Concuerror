-module(last_zero).

-export([scenarios/0, test/0]).

scenarios() ->
  [{test, B, full} || B <- [0,1,5]].

-define(TABLE, table).

test() ->
  last_zero(3).

last_zero(N) ->
  ?TABLE = ets:new(?TABLE, [public, named_table]),
  lists:foreach(fun(X) -> ets:insert(table, {X, 0}) end, lists:seq(0,N)),
  spawn(fun() -> reader(N) end),
  lists:foreach(fun(X) -> spawn(fun() -> writer(X) end) end, lists:seq(1,N)),
  receive after infinity -> ok end.

reader(0) -> ok;
reader(N) ->
  R = read(N),
  case R of
    0 -> ok;
    _ -> reader(N - 1)
  end.

writer(X) ->
  R = read(X - 1),
  write(X, R + 1).

write(Key, Value) ->
  ets:insert(?TABLE, {Key, Value}).

read(Key) ->
  [{Key, V}] = ets:lookup(?TABLE, Key),
  V.
