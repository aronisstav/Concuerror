-module(stacktrace_vs_exit).

-export([test/0]).

-export([scenarios/0]).

-concuerror_options_forced([{parallel, true}]).

%%------------------------------------------------------------------------------

scenarios() -> [{test, inf, optimal}].

%%------------------------------------------------------------------------------

test() ->
  spawn(fun() -> erlang:get_stacktrace() end).
