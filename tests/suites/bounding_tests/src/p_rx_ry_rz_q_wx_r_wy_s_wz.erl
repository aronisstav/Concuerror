-module(p_rx_ry_rz_q_wx_r_wy_s_wz).

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
  spawn(fun() -> work(4) end),
  receive after infinity -> ok end.

work(1) ->
  read(x),
  read(y),
  read(z);
work(2) ->
  write(x,1);
work(3) ->
  write(y,1);
work(4) ->
  write(z,1).

write(Key, Value) ->
  ets:insert(?TABLE, {Key, Value}).

read(Key) ->
  [{Key, V}] = ets:lookup(?TABLE, Key),
  erlang:display({Key,V}),
  V.
