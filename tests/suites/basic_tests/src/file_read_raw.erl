-module(file_read_raw).

-export([scenarios/0]).
-export([test/0]).

scenarios() ->
    [{test, inf, dpor}].

test() ->
    {ok, Foo} = file:open("foo", [read,raw]),
    file:write(Foo, "test").
