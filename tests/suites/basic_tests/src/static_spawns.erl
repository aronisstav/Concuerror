-module(static_spawns).
-export([scenarios/0]).
-export([test1/0, test2/0]).

%
% Tests that statically spawning processes works
%

-concuerror_options_forced([{max_processes, 5}]).

scenarios() -> [{test1, inf, optimal},
				{test2, inf, optimal, crash}].

% 5 processes are getting spawned in total
test1() ->
    spawn_procs(4).

% 6 processes are getting spawned in total
test2() ->
	spawn_procs(5).

spawn_procs(0) -> ok;
spawn_procs(N) ->
	spawn(fun() -> ok end),
	spawn_procs(N-1).
