-module(p_wx_wy_q_wz_rx_r_rz_ry).

-export([scenarios/0]).
-export([test/0]).

scenarios() ->
    [{test, B, full} || B <- [0,1]].

-define(TABLE, table).

test() ->
  ?TABLE = ets:new(?TABLE, [public, named_table]),
  write(x,0),
  write(y,0),
  write(z,0),
  spawn(fun() -> work(1) end),
  spawn(fun() -> work(2) end),
  spawn(fun() -> work(3) end),
  receive after infinity -> ok end.

work(1) ->
  write(x,1),
  write(y,1);
work(2) ->
  write(z,1),
  read(x);
work(3) ->
  read(z),
  read(y).

write(Key, Value) ->
  ets:insert(?TABLE, {Key, Value}).

read(Key) ->
  [{Key, V}] = ets:lookup(?TABLE, Key),
  erlang:display({Key,V}),
  V.
