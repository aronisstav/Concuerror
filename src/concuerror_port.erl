%% -*- erlang-indent-level: 2 -*-

-module(concuerror_port).

-export([open_port/3, port_command/3, convert_port_msgs/1, new/0]).

%%------------------------------------------------------------------------------

-spec open_port(term(), term(), timeout()) -> port().

open_port(PortName, PortSettings, Timeout) ->
  Handler = "erl -noshell -pa ebin -s concuerror_port new -s erlang halt",
  Port = erlang:open_port({spawn, Handler}, []),
  write_terms(Port, [PortName, PortSettings, Timeout]),
  Port.

-spec port_command(port(), term(), [term()]) -> ok.

port_command(Port, Data, OptionList) ->
  write_terms(Port, [Data, OptionList]).

-spec convert_port_msgs(port()) -> ok.

convert_port_msgs(Port) ->
  receive {Port, {data, "done.\n"}} -> ok end,
  Marker = make_ref(),
  self() ! Marker,
  convert_port_msgs(Port, Marker).

%%------------------------------------------------------------------------------

-spec new() -> no_return().

new() ->
  [PortName, PortSettings, Timeout] = read_terms(3),
  Port = erlang:open_port(PortName, PortSettings),
  loop(Port, Timeout).

%%------------------------------------------------------------------------------

write_terms(_Port, []) -> ok;
write_terms(Port, [Data|Rest]) ->
  write_term(Port, Data),
  write_terms(Port, Rest).

write_term(Port, Term) ->
  TermString = lists:flatten(io_lib:format("~w.~n",[Term])),
  true = erts_internal:port_command(Port, TermString, []).

read_terms(0) -> [];
read_terms(N) ->
  {ok, Term} = io:read(""),
  [Term|read_terms(N-1)].

%%------------------------------------------------------------------------------

loop(Port, Timeout) ->
  port_forward(Port, Timeout),
  [Data, OptionsList] = read_terms(2),
  case Data =:= reset of
    true ->
      port_close(Port),
      new();
    false ->
      erlang:port_command(Port, Data, OptionsList),
      loop(Port, Timeout)
  end.

port_forward(Port, Timeout) ->
  receive
    {'EXIT', Port, Reason} ->
      term_forward({'EXIT', Reason}),
      done();
    {Port, close} ->
      term_forward(close),
      done();
    {Port, Data} ->
      term_forward(Data),
      port_forward(Port, Timeout)
  after
    Timeout -> done()
  end.

term_forward(Term) ->
  io:format("~w.\n",[Term]).

done() ->
  term_forward(done).
%%------------------------------------------------------------------------------

convert_port_msgs(Port, Marker) ->
  receive
    Marker -> ok;
    {Port, {data, ForwardedData}} ->
      {ok, Tokens, _} = erl_scan:string(ForwardedData),
      {ok, Data} = erl_parse:parse_term(Tokens),
      case Data of
        {data, _} ->
          self() ! {Port, Data};
        {'EXIT', Reason} ->
          self() ! {'EXIT', Port, Reason};
        close ->
          self() ! {Port, close}
      end,
      convert_port_msgs(Port, Marker);
    Unknown ->
      exit({port_conversion_failed, Unknown})
  end.

