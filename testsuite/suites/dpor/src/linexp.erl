-module(linexp).

-export([test/0, test/1]).
-export([scenarios/0]).

-ifndef(SIZE).
-define(SIZE, 6).
-endif.

scenarios() -> [{test, inf, R} || R <- [dpor, source]].

%%%-----------------------------------------------------------------------------

test() ->
  test(?SIZE).

%%%-----------------------------------------------------------------------------

test(Total) ->
  ets:new(table, [public, named_table]),
  _ = [write({X, N}, 0) || X <- [x, y, z], N <- lists:seq(1, Total)],
  _ = spawn(fun() -> read({x, Total}) end),
  spawn_all_ps(Total - 1),
  spawn_qrs(1),
  block().

spawn_qrs(N) ->
  Q_Fun = fun() -> write({y, N}, 1) end,
  R_Fun =
    fun() ->
        case read({y, N}) of
          0 -> write({z, N}, 1);
          1 -> ok
        end
    end,
  S_Fun =
    fun() ->
        case read({z, N}) of
          0 -> ok;
          1 ->
            case read({y, N}) of
              0 -> write({x, N}, 1);
              1 -> ok
            end
        end
    end,
  _ = spawn(Q_Fun),
  _ = spawn(R_Fun),
  _ = spawn(S_Fun),
  ok.

spawn_all_ps(0) -> ok;
spawn_all_ps(N) ->
  P_Fun =
    fun() ->
        case read({x, N}) of
          1 -> spawn_qrs(N + 1);
          0 -> ok
        end
    end,
  _ = spawn(P_Fun),
  spawn_all_ps(N - 1).

%%%-----------------------------------------------------------------------------

write(K, V) ->
  ets:insert(table, {K, V}).

read(K) ->
  [{K, V}] = ets:lookup(table, K),
  V.

%%%-----------------------------------------------------------------------------

block() ->
  receive after infinity -> ok end.
