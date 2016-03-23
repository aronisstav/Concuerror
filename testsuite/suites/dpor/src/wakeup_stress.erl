-module(wakeup_stress).

-export([scenarios/0]).
-export([test/0, test/1]).

-export([test_1/0, test_2/0, test_3/0, test_4/0, test_5/0,
         test_6/0, test_7/0, test_8/0, test_9/0]).

%%------------------------------------------------------------------------------

scenarios() -> [{test, inf, R} || R <- [dpor, source]].

%%------------------------------------------------------------------------------

-define(N, 5).

test() ->
  test(?N).

%%------------------------------------------------------------------------------

test_1() -> test(1).
test_2() -> test(2).
test_3() -> test(3).
test_4() -> test(4).
test_5() -> test(5).
test_6() -> test(6).
test_7() -> test(7).
test_8() -> test(8).
test_9() -> test(9).

%%------------------------------------------------------------------------------

%% The code matches the example given in the paper, with some tricks to deal
%% with the subtleties of Erlang. The two shared variables are implemented as
%% entries in an ETS table, that each thread sets to its PID. All processes are
%% chained in a simple ring to avoid races with the deletion of the ETS
%% table. The barrier is enforced by having the operation by 'Last' happen after
%% all processes that write on counter2 are done.

test(N) ->
  table = ets:new(table, [public, named_table]),
  true = ets:insert(table, {counter1, 0}),
  true = ets:insert(table, {counter2, 0}),
  FirstFun =
    fun(Next) ->
        _ = ets:insert(table, {counter1, self()}),
        receive token -> Next ! token end
    end,
  OthersFun =
    fun(Next) ->
        _ = ets:insert(table, {counter2, self()}),
        receive token -> Next ! token end
    end,
  LastFun =
    fun(Next) ->
        receive
          token ->
            _ = ets:insert(table, {counter1, self()}),
            Next ! token
        end
    end,
  First = spawn_workers(1, FirstFun, self()),
  Last = spawn_workers(1, LastFun, First),
  Others = spawn_workers(N, OthersFun, Last),
  Others ! token,
  receive token -> ok end.

spawn_workers(0, _, Next) ->
  Next;
spawn_workers(N, WorkerFun, Next) ->
  W = spawn(fun() -> WorkerFun(Next) end),
  spawn_workers(N - 1, WorkerFun, W).
