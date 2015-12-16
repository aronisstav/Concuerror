-module(wakeup_stress).

-export([scenarios/0]).
-export([test/0, test/2]).

scenarios() -> [{test, inf, R} || R <- [dpor, source]].

test() ->
  test(8, 10).

test(N, M) ->
  table = ets:new(table, [public, named_table]),
  true = ets:insert(table, {counter, 0}),
  WorkerFun =
    fun(Next) ->
        noise(M * 50),
        _ = ets:update_counter(table, counter, 1),
        receive token -> Next ! token end
    end,
  First = spawn_workers(N, WorkerFun, self()),
  First ! token,
  receive token -> ok end,
  ets:lookup(table, counter).

spawn_workers(0, _, Next) ->
  Next;
spawn_workers(N, WorkerFun, Next) ->
  W = spawn(fun() -> WorkerFun(Next) end),
  spawn_workers(N - 1, WorkerFun, W).

noise(0) -> ok;
noise(N) ->
  _ = ets:lookup(table, noise),
  noise(N - 1).
