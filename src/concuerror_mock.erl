%% -*- erlang-indent-level: 2 -*-

-module(concuerror_mock).

-export([has_mock/4]).

-export_type([mock_spec/0]).

-type mock_spec() :: term().

-spec has_mock(module(), atom(), arity(), mock_spec()) ->
                  {true, mfa()} | false.

has_mock(Module, Name, Arity, [{From,To}|Rest]) ->
  erlang:display({Module, Name, Arity, {From,To}}),
  case From of
    {Module, Name, Arity} ->
      {true, To};
    Module when is_atom(Module) ->
      erlang:display({match, To}),
      {true, {To, Name, Arity}};
    _ ->
      has_mock(Module, Name, Arity, Rest)
  end;
has_mock(_Module, _Name, _Arity, _) ->
  false.
