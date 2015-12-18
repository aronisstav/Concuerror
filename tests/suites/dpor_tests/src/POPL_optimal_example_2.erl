-module('POPL_optimal_example_2').

-export([test/0]).
-export([scenarios/0]).

scenarios() -> [{test, inf, R} || R <- [dpor, source]].

%%%-----------------------------------------------------------------------------

test() ->
  test(2).

%%%-----------------------------------------------------------------------------

test(Total) ->
  ets:new(table, [public, named_table]),
  _ = [in({X, N}, 0) || X <- [x, y, z], N <- lists:seq(1, Total)],
  _ = spawn(fun() -> out({x, Total}) end),
  create(Total - 1),
  unlock(1),
  block().

unlock(N) ->
  YRoutine = fun() -> in({y, N}, 1) end,
  ZRoutine =
    fun() ->
        case out({y, N}) of
          0 -> in({z, N}, 1);
          1 -> ok
        end
    end,
  XRoutine =
    fun() ->
        case out({z, N}) of
          0 -> ok;
          1 ->
            case out({y, N}) of
              0 -> in({x, N}, 1);
              1 -> ok
            end
        end
    end,
  _ = spawn(YRoutine),
  _ = spawn(ZRoutine),
  _ = spawn(XRoutine),
  ok.

create(0) -> ok;
create(N) ->
  Fun =
    fun() ->
        case out({x, N}) of
          1 -> unlock(N + 1);
          0 -> ok
        end
    end,
  _ = spawn(Fun),
  create(N - 1).

%%%-----------------------------------------------------------------------------

in(K, V) ->
  ets:insert(table, {K, V}).

out(K) ->
  [{K, V}] = ets:lookup(table, K),
  V.

%%%-----------------------------------------------------------------------------

block() ->
  receive after infinity -> ok end.
