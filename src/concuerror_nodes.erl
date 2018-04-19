%% -*- erlang-indent-level: 2 -*-

-module(concuerror_nodes).

%%% Interface to concuerror.erl

-export([start/1, clear/1]).

-include("concuerror.hrl").

-spec start(concuerror_options:options()) -> [node()].

start(Options) ->
  Name = hashed_name(Options),
  ok = start_epmd(?epmd_tries),
  _ = net_kernel:start([Name, shortnames]), %TODO check errors
  {ok, Host} = inet:gethostname(),
  SchedulerNodeName = atom_to_list(Name) ++ "_1",
  Path = path_to_ebin(),
  Args = "-boot start_clean -noshell -pa " ++ Path,
  {ok, Node} = slave:start(Host, SchedulerNodeName, Args),
  [Node].

start_epmd(0) -> epmd_not_starting;
start_epmd(TriesLeft) ->
  case os:cmd("epmd -names") of 
    ?epmd_not_running_response ->
      _ = os:cmd("epmd -daemon"),
      start_epmd(TriesLeft - 1);
    _ ->
      ok
  end.

hashed_name(Args) ->
  PathValue = file:get_cwd(),
  Hash = binary:decode_unsigned(erlang:md5(term_to_binary([PathValue|Args]))),
  [HashString] = io_lib:format("~.16b",[Hash]),
  Name = "node" ++ HashString,
  list_to_atom(Name).

-spec clear([node()]) -> ok | {error, not_allowed} | {error, not_found}.

clear([]) ->
  ok;
clear([Node|Rest]) ->
  slave:stop(Node),
  clear(Rest).

path_to_ebin() ->
  ModulePath = code:which(?MODULE),
  filename:dirname(ModulePath).

%% -spec send_ets_tables(pid()) -> ok.

%% %% Currently need to send concuerror_instrumented ets_table
%% send_ets_tables(Target) ->
%%   Target ! {concuerror_instrumented, ets:tab2list(concuerror_instrumented)}.

%% -spec get_ets_tables() -> true.

%% get_ets_tables() ->
%%   receive
%%     {concuerror_instrumented, EtsList} ->
%%       concuerror_instrumented = ets:new(concuerror_instrumented, [named_table, public]),
%%       ets:insert(concuerror_instrumented, EtsList)
%%   end.