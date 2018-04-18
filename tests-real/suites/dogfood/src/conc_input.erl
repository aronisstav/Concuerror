-module(conc_input).

-export([test/0]).

%% test() ->
%%   ok.

%% test() ->
%%   exit(bad).

%% test() ->
%%   receive
%%   after
%%     0 -> ok
%%   end.

%% test() ->
%%   receive
%%   after
%%     infinity -> ok
%%   end.

%% test() ->
%%   self() ! ok.

%% test() ->
%%   self() ! ok,
%%   receive
%%     Msg when Msg =/= ok -> exit(alarm);
%%     ok -> ok
%%   end.

%% test() ->
%%   spawn(fun() -> ok end).

%% test() ->
%%   spawn(fun() -> exit(abnormal) end).

%% test() ->
%%   spawn(fun() -> receive ok -> ok end end),
%%   self() ! ok.

%% test() ->
%%   spawn(fun() -> self() ! ok end),
%%   receive ok -> ok end.

%% test() ->
%%   spawn(
%%     fun() ->
%%         receive
%%           Else when Else =/= ok -> exit(alarm);
%%           ok -> ok
%%         end
%%     end) ! ok.

%% test() ->
%%   spawn(
%%     fun() ->
%%         receive
%%           ok -> ok
%%         after
%%           0 -> ok
%%         end
%%     end) ! ok.

%% test() ->
%%   P = self(),
%%   spawn(fun() -> P ! ok end),
%%   %register(foo, self()),
%%   receive
%%     ok -> ok
%%   after
%%     0 -> ok
%%   end,
%%   receive after infinity -> ok end.

test() -> readers(2).

readers(N) ->
  ets:new(tab, [public, named_table]),
  Writer = fun() -> ets:insert(tab, {x, 42}) end,
  Reader = fun() -> ets:lookup(tab, x) end,
  spawn(Writer),
  [spawn(fun() -> Reader() end) || _ <- lists:seq(1, N)],
  receive after infinity -> deadlock end.
