-module(exit_self).

-export([scenarios/0]).
-export([concuerror_options/0]).
-export([test1/0, test2/0, test3/0,
         test4/0, test5/0, test6/0
        ]).

concuerror_options() ->
    [{treat_as_normal, killed},
     {treat_as_normal, error}].

scenarios() ->
    [{T, inf, dpor} || T <- [test1,test2,test3,test4,test5,test6]].

test1() ->
    exit_self(false, normal).
test2() ->
    exit_self(false, error).
test3() ->
    exit_self(false, kill).
test4() ->
    exit_self(true, normal).
test5() ->
    exit_self(true, error).
test6() ->
    exit_self(true, kill).

exit_self(TrapExit, Signal) ->
    P = self(),
    {C, R} =
        spawn_monitor(
          fun() ->
                  process_flag(trap_exit, TrapExit),
                  exit(self(), Signal),
                  P ! still_alive
          end),
    Reason =
        case Signal =:= kill of
            true -> killed;
            false -> Signal
        end,
    receive
        {'DOWN', R, process, C, Reason} -> ok;
        still_alive ->
            (Signal =:= normal)
                orelse
                  (TrapExit andalso Signal =/= kill)
                orelse
                exit(unacceptable)
    end.
            
    
