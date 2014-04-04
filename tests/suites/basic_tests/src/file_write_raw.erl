-module(file_write_raw).

-export([scenarios/0]).
-export([test/0]).

scenarios() ->
    [{test, inf, dpor}].

test() ->
    {ok, Foo} = file:open("foo", [write,raw]),
    file:write(Foo, "test").
