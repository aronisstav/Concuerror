%% -*- erlang-indent-level: 2 -*-

-module(concuerror_logger).

-export([start/1, complete/2, plan/1, log/5, race/3, stop/2, print/3, time/2]).
-export([skip_conservative/1]).
-export([graph_set_node/3, graph_new_node/5, graph_race/4]).

-include("concuerror.hrl").

-define(TICKER_TIMEOUT, 500).
%%------------------------------------------------------------------------------

-type stream() :: 'standard_io' | 'standard_error' | 'race' | file:filename().
-type graph_data() ::
        {file:io_device(), reference() | 'init', reference() | 'none'}.

%%------------------------------------------------------------------------------

-ifdef(BEFORE_OTP_17).
-type unique_ids() :: set().
-else.
-type unique_ids() :: sets:set(integer()).
-endif.

%%------------------------------------------------------------------------------

-ifdef(BEFORE_OTP_18).

-type timestamp() :: erlang:timestamp().
timestamp() ->
  erlang:now().
timediff(After, Before) ->
  timer:now_diff(After, Before) / 1000000.

-else.

-type timestamp() :: integer().
timestamp() ->
  erlang:monotonic_time(milli_seconds).
timediff(After, Before) ->
  (After - Before) / 1000.

-endif.

%%------------------------------------------------------------------------------

-record(logger_state, {
          already_emitted = sets:new() :: unique_ids(),
          emit_logger_tips = initial   :: 'initial' | 'false',
          errors = 0                   :: non_neg_integer(),
          graph_data                   :: graph_data() | 'undefined',
          log_msgs = []                :: [string()],
          output                       :: file:io_device(),
          output_name                  :: string(),
          print_depth                  :: pos_integer(),
          rate_timestamp = timestamp() :: timestamp(),
          rate_prev = 0                :: non_neg_integer(),
          streams = []                 :: [{stream(), [string()]}],
          timestamp = timestamp()      :: timestamp(),
          ticker = none                :: pid() | 'none' | 'show',
          traces_conservative_skip = 0 :: non_neg_integer(),
          traces_explored = 0          :: non_neg_integer(),
          traces_ssb = 0               :: non_neg_integer(),
          traces_total = 0             :: non_neg_integer(),
          verbosity                    :: non_neg_integer()
         }).

%%------------------------------------------------------------------------------

-spec start(options()) -> pid().

start(Options) ->
  Parent = self(),
  P = spawn_link(fun() -> run(Parent, Options) end),
  receive
    logger_ready -> P
  end.

run(Parent, Options) ->
  [{Output, OutputName},SymbolicNames,Processes,Modules] =
    get_properties(
      [output,symbolic_names,processes,modules],
      Options),
  Fun = fun({M}, _) -> ?log(self(), ?linfo, "Instrumented ~p~n", [M]) end,
  ets:foldl(Fun, ok, Modules),
  ets:insert(Modules, {{logger}, self()}),
  ok = setup_symbolic_names(SymbolicNames, Processes),
  io_lib = concuerror_loader:load(io_lib, Modules),
  PrintableOptions =
    delete_props(
      [graph, modules, output, processes, timers, verbosity],
      Options),
  separator(Output, $#),
  io:format(Output,
            "Concuerror started with options:~n"
            "  ~p~n",
            [lists:sort(PrintableOptions)]),
  separator(Output, $#),
  GraphData = graph_preamble(?opt(graph, Options)),
  State =
    #logger_state{
       graph_data = GraphData,
       output = Output,
       output_name = OutputName,
       print_depth = ?opt(print_depth, Options),
       verbosity = ?opt(verbosity, Options)
      },
  Parent ! logger_ready,
  loop_entry(State).

get_properties(Props, PropList) ->
  get_properties(Props, PropList, []).

get_properties([], _, Acc) -> lists:reverse(Acc);
get_properties([Prop|Props], PropList, Acc) ->
  PropVal = proplists:get_value(Prop, PropList),
  get_properties(Props, PropList, [PropVal|Acc]).

delete_props([], Proplist) ->
  Proplist;
delete_props([Key|Rest], Proplist) ->
  delete_props(Rest, proplists:delete(Key, Proplist)).

-spec plan(logger()) -> ok.

plan(Logger) ->
  Logger ! plan,
  ok.

-spec complete(logger(), concuerror_warnings()) -> ok.

complete(Logger, Warnings) ->
  Logger ! {complete, Warnings},
  ok.

-spec log(logger(), log_level(), term(), string(), [term()]) -> ok.

log(Logger, Level, Tag, Format, Data) ->
  Logger ! {log, Level, Tag, Format, Data},
  ok.

-spec stop(logger(), term()) -> ok.

stop(Logger, Status) ->
  Logger ! {close, Status, self()},
  receive
    closed -> ok
  end.

-spec print(logger(), stream(), string()) -> ok.

print(Logger, Type, String) ->
  Logger ! {print, Type, String},
  ok.

-spec time(logger(), term()) -> ok.

time(Logger, Tag) ->
  Logger ! {time, Tag},
  ok.

-spec race(logger(), {index(), event()}, {index(), event()}) -> ok.

race(Logger, EarlyEvent, Event) ->
  Logger ! {race, EarlyEvent, Event},
  ok.

-spec skip_conservative(logger()) -> ok.

skip_conservative(Logger) ->
  Logger ! skip_conservative,
  ok.
  
%%------------------------------------------------------------------------------

loop_entry(State) ->
  #logger_state{output_name = OutputName, verbosity = Verbosity} = State,
  Ticker =
    case (Verbosity =:= ?lquiet) orelse (Verbosity >= ?ldebug) of
      true -> none;
      false ->
        Timestamp = format_utc_timestamp(),
        to_stderr("Concuerror started at ~s~n", [Timestamp]),
        to_stderr("Writing results in ~s~n~n~n", [OutputName]),
        Self = self(),
        spawn_link(fun() -> ticker(Self) end)
    end,
  loop(State#logger_state{ticker = Ticker}).

loop(State) ->
  receive
    Message when Message =/= tick -> loop(Message, State)
  end.

loop(Message,
     #logger_state{
        emit_logger_tips = initial,
        errors = Errors,
        traces_explored = 10,
        traces_total = TracesTotal
       } = State) ->
  case TracesTotal > 250 of
    true ->
      ManyMsg =
        "A lot of events in this test are racing. You can see such pairs"
        " by using --show_races true. You may want to consider reducing some"
        " parameters in your test (e.g. number of processes or events).~n",
      ?log(self(), ?ltip, ManyMsg, []);
    false -> ok
  end,
  case Errors =:= 10 of
    true ->
      ErrorsMsg =
        "Every interleaving explored so far had some error. This can make later"
        " debugging difficult, as the generated report will include too much"
        " info. You may want to consider refactoring your code, or using the"
        " appropriate options to filter out irrelevant errors.~n",
      ?log(self(), ?ltip, ErrorsMsg, []);
    false -> ok
  end,
  loop(Message, State#logger_state{emit_logger_tips = false});

loop(Message, State) ->
  #logger_state{
     already_emitted = AlreadyEmitted,
     errors = Errors,
     log_msgs = LogMsgs,
     output = Output,
     print_depth = PrintDepth,
     streams = Streams,
     ticker = Ticker,
     timestamp = Timestamp,
     traces_conservative_skip = TracesSkip,
     traces_explored = TracesExplored,
     traces_ssb = TracesSSB,
     traces_total = TracesTotal,
     verbosity = Verbosity
    } = State,
  case Message of
    {time, Tag} ->
      Now = timestamp(),
      Diff = timediff(Now, Timestamp),
      Msg = "~nTimer: +~5.2fs ~s~n",
      loop(
        {log, ?ltiming, none, Msg, [Diff, Tag]},
        State#logger_state{timestamp = Now});
    {race, EarlyEvent, Event} ->
      Msg =
        io_lib:format(
          "* ~s~n  ~s~n",
          [concuerror_printer:pretty_s(E, PrintDepth)
           || E <- [EarlyEvent,Event]]),
      loop({print, race, Msg}, State);
    {log, Level, Tag, Format, Data} ->
      {NewLogMsgs, NewAlreadyEmitted} =
        case Tag =/= ?nonunique andalso sets:is_element(Tag, AlreadyEmitted) of
          true -> {LogMsgs, AlreadyEmitted};
          false ->
            case Verbosity < Level of
              true  -> ok;
              false -> printout(State, Level, Format, Data)
            end,
            NLM =
              case Level < ?ltiming of
                true  -> orddict:append(Level, {Format,Data}, LogMsgs);
                false -> LogMsgs
              end,
            NAE =
              case Tag =/= ?nonunique of
                true -> sets:add_element(Tag, AlreadyEmitted);
                false -> AlreadyEmitted
              end,
            {NLM, NAE}
        end,
      loop(State#logger_state{
             already_emitted = NewAlreadyEmitted,
             log_msgs = NewLogMsgs});
    {graph, Command} ->
      loop(graph_command(Command, State));
    {close, Status, Scheduler} ->
      case is_pid(Ticker) of
        true -> Ticker ! stop;
        false -> ok
      end,
      case Errors =:= 0 of
        true -> io:format(Output, "  No errors found!~n",[]);
        false -> ok
      end,
      separator(Output, $#),
      print_log_msgs(Output, LogMsgs),
      Format = "Done! (Exit status: ~p)~n  Summary: ",
      IntMsg = interleavings_message(State),
      io:format(Output, Format, [Status]),
      io:format(Output, "~s", [IntMsg]),
      ok = file:close(Output),
      ok = graph_close(State),
      case Verbosity =:= ?lquiet of
        true -> ok;
        false -> printout(State#logger_state{ticker = show}, Format, [Status])
      end,
      Scheduler ! closed,
      ok;
    plan ->
      NewState = State#logger_state{traces_total = TracesTotal + 1},
      FinalState = update_on_ticker(NewState),
      loop(FinalState);
    skip_conservative ->
      NewState =
        State#logger_state{
          traces_conservative_skip = TracesSkip + 1,
          traces_total = TracesTotal - 1
         },
      FinalState = update_on_ticker(NewState),
      loop(FinalState);
    {print, Type, String} ->
      NewStreams = orddict:append(Type, String, Streams),
      NewState = State#logger_state{streams = NewStreams},
      loop(NewState);
    {complete, Warn} ->
      NewErrors =
        case Warn of
          {Warnings, TraceInfo} when Warnings =/= [sleep_set_block] ->
            NE = Errors + 1,
            case NE > 1 of
              true -> separator(Output, $#);
              false -> ok
            end,
            io:format(Output, "Erroneous interleaving ~p:~n", [NE]),
            WarnStr =
              [concuerror_printer:error_s(W, PrintDepth) || W <-Warnings],
            io:format(Output, "~s", [WarnStr]),
            separator(Output, $-),
            print_streams([S || S = {T, _} <- Streams, T =/= race], Output),
            io:format(Output, "Interleaving info:~n", []),
            concuerror_printer:pretty(Output, TraceInfo, PrintDepth),
            print_streams([S || S = {T, _} <- Streams, T =:= race], Output),
            NE;
          _ -> Errors
        end,
      NewSSB =
        case Warn =:= {[sleep_set_block], []} of
          true -> TracesSSB + 1;
          false -> TracesSSB
        end,
      {GraphMark, Color} =
        if NewSSB =/= TracesSSB -> {"Sleep Set Block","yellow"};
           NewErrors =/= Errors ->
            DeadlockS =
              case Warn of
                {[{deadlock, Ps}|_], _} ->
                  io_lib:format("(~p blocked)", [[P || {P,_} <- Ps]]);
                _ -> ""
              end,
            {"Error" ++ DeadlockS,"red"};
           true -> {"Ok","lime"}
        end,
      _ = graph_command({status, TracesExplored, GraphMark, Color}, State),
      NewState =
        State#logger_state{
          streams = [],
          traces_explored = TracesExplored + 1,
          traces_ssb = NewSSB,
          errors = NewErrors
         },
      FinalState = update_on_ticker(NewState),
      loop(FinalState)
  end.

format_utc_timestamp() ->
  TS = os:timestamp(),
  {{Year, Month, Day}, {Hour, Minute, Second}} =
    calendar:now_to_universal_time(TS),
  Mstr =
    element(Month, {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug",
                    "Sep", "Oct", "Nov", "Dec"}),
  io_lib:format("~2..0w ~s ~4w ~2..0w:~2..0w:~2..0w",
                [Day, Mstr, Year, Hour, Minute, Second]).

printout(#logger_state{ticker = Ticker} = State, Format, Data)
  when Ticker =/= none ->
  IntMsg = interleavings_message(State),
  clear_progress(),
  to_stderr(Format, Data),
  to_stderr("~s", [IntMsg]);
printout(_, Format, Data) ->
  to_stderr(Format, Data).

printout(State, Level, Format, Data) ->
  Tag = verbosity_to_string(Level),
  Pad = verbosity_pad(Level),
  NewFormat = Tag ++ Pad ++ Format,
  printout(State, NewFormat, Data).

print_log_msgs(Output, LogMsgs) ->
  ForeachInner = fun({Format, Data}) -> io:format(Output,Format,Data) end,
  Foreach =
    fun({Type, Messages}) ->
        Header = verbosity_to_string(Type),
        Suffix =
          case Type of
            ?linfo    -> "";
            _         -> "s"
          end,
        io:format(Output, "~s~s:~n", [Header, Suffix]),
        separator(Output, $-),
        lists:foreach(ForeachInner, Messages),
        io:format(Output, "~n", []),
        separator(Output, $#)
    end,
  lists:foreach(Foreach, LogMsgs).

verbosity_to_string(Level) ->
  case Level of
    ?lerror   -> "Error";
    ?lwarning -> "Warning";
    ?ltip     -> "Tip";
    ?linfo    -> "Info";
    _ -> ""
  end.

verbosity_pad(Level) ->
  case Level of
    ?lerror   -> ": ";
    ?lwarning -> ": ";
    ?ltip     -> ": ";
    ?linfo    -> ": ";
    _ -> ""
  end.

clear_progress() ->
  to_stderr("~c[1A~c[2K\r", [27, 27]).

to_stderr(Format, Data) ->
  io:format(standard_error, Format, Data).

ticker(Logger) ->
  Logger ! tick,
  receive
    stop -> ok
  after
    ?TICKER_TIMEOUT -> ticker(Logger)
  end.

update_on_ticker(State) ->
  case has_tick() of
    true  ->
      {Rate, NewState} = update_rate(State),
      printout(State, "~s", [Rate]),
      NewState;
    false -> State
  end.

update_rate(State) ->
  #logger_state{
     rate_timestamp = Old,
     rate_prev = Prev,
     traces_explored = Current} = State,
  New = timestamp(),
  Time = timediff(New, Old),
  Diff = Current - Prev,
  Rate = (Diff / Time),
  RateStr = io_lib:format("(~5.1f interleavings/s) ",[Rate]),
  {RateStr, State#logger_state{rate_timestamp = New, rate_prev = Current}}.

has_tick() ->
  has_tick(false).

has_tick(Result) ->
  receive
    tick -> has_tick(true)
  after
    0 -> Result
  end.

separator_string(Char) ->
  lists:duplicate(80, Char).

separator(Output, Char) ->
  io:format(Output, "~s~n~n", [separator_string(Char)]).

print_streams(Streams, Output) ->
  Fold =
    fun(Tag, Buffer, ok) ->
        print_stream(Tag, Buffer, Output),
        ok
    end,
  orddict:fold(Fold, ok, Streams).

print_stream(Tag, Buffer, Output) ->
  io:format(Output, tag_to_filename(Tag) ++ ":~n", []),
  io:format(Output, "~s~n", [Buffer]),
  case Tag =/= race of
    true ->
      io:format(Output, "~n", []),
      separator(Output, $-);
    false -> ok
  end.

tag_to_filename(standard_io) -> "Standard Output";
tag_to_filename(standard_error) -> "Standard Error";
tag_to_filename(race) ->
  separator_string($-) ++
    "~n~nPairs of racing instructions";
tag_to_filename(Filename) when is_list(Filename) ->
  io_lib:format("Text printed to ~s", [Filename]).

interleavings_message(State) ->
  #logger_state{
     errors = Errors,
     traces_conservative_skip = TracesSkip,
     traces_explored = TracesExplored,
     traces_ssb = TracesSSB,
     traces_total = TracesTotal
    } = State,
  SSB =
    case TracesSSB =:= 0 of
      true -> "";
      false -> io_lib:format(" (~p sleep-set blocked)",[TracesSSB])
    end,
  Skip =
    case TracesSkip =:= 0 of
      true -> "";
      false -> io_lib:format(" (+~p conservative skipped)",[TracesSkip])
    end,
  io_lib:format("~p errors, ~p/~p interleavings explored~s~s~n",
                [Errors, TracesExplored, TracesTotal, SSB, Skip]).

%%------------------------------------------------------------------------------

-spec graph_set_node(logger(), reference(), reference()) -> ok.

graph_set_node(Logger, Parent, Sibling) ->
  Logger ! {graph, {set_node, Parent, Sibling}},
  ok.

-spec graph_new_node(logger(), reference(), index(), event(), integer()) -> ok.

graph_new_node(Logger, Ref, Index, Event, BoundConsumed) ->
  Logger ! {graph, {new_node, Ref, Index, Event, BoundConsumed}},
  ok.

-spec graph_race(logger(), reference(), reference(), string()) -> ok.
graph_race(Logger, EarlyRef, Ref, Color) ->
  Logger ! {graph, {race, EarlyRef, Ref, Color}},
  ok.

graph_preamble(undefined) -> undefined;
graph_preamble(GraphFile) ->
  io:format(
    GraphFile,
    "digraph {~n"
    "  graph [ranksep=0.3]~n"
    "  node [shape=box,width=7,fontname=Monospace]~n"
    "  init [label=\"Initial\"];~n"
    "  subgraph {~n", []),
  {GraphFile, init, none}.

graph_command(_Command, #logger_state{graph_data = undefined} = State) -> State;
graph_command(Command, State) ->
  #logger_state{
     graph_data = {GraphFile, Parent, Sibling} = Graph,
     print_depth = PrintDepth
    } = State,
  NewGraph =
    case Command of
      {new_node, Ref, I, Event, BoundConsumed} ->
        ErrorS =
          case Event#event.event_info of
            #exit_event{reason = normal} ->
              ",color=lime,penwidth=5";
            #exit_event{} ->
              ",color=red,penwidth=5";
            #builtin_event{status = {crashed, _}} ->
              ",color=orange,penwidth=5";
            _ -> ""
          end,
        Label = concuerror_printer:pretty_s({I,Event#event{location=[]}}, PrintDepth - 19),
        EnabledLabel =
          case BoundConsumed =:= 0 of
            true -> "    ";
            false -> io_lib:format("!~2w",[BoundConsumed])
          end,
        io:format(
          GraphFile,
          "    \"~p\" [label=\"~s ~s\\l\"~s];~n",
          [Ref, EnabledLabel, Label, ErrorS]),
        case Sibling =:= none of
          true ->
            io:format(GraphFile,"~s[weight=1000];~n",[ref_edge(Parent, Ref)]);
          false ->
            io:format(
              GraphFile,
              "~s[style=invis,weight=1];~n"
              "~s[constraint=false];~n",
              [ref_edge(Parent, Ref), ref_edge(Sibling, Ref)])
        end,
        {GraphFile, Ref, none};
      {race, EarlyRef, Ref, Color} ->
        io:format(
          GraphFile,
          "~s[constraint=false, color=~s, dir=back, penwidth=3, style=dashed];~n",
          [dref_edge(EarlyRef, Ref), Color]),
        Graph;
      {set_node, NewParent, NewSibling} ->
        io:format(
          GraphFile,
          "  }~n"
          "  subgraph{~n",
          []),
        {GraphFile, NewParent, NewSibling};
      {status, Count, String, Color} ->
        Ref = make_ref(),
        io:format(
          GraphFile,
          "    \"~p\" [label=\"i~p: ~s\",style=filled,fillcolor=~s];~n"
          "~s[weight=1000];~n",
          [Ref, Count+1, String, Color, ref_edge(Parent, Ref)]),
        Graph
    end,
  State#logger_state{graph_data = NewGraph}.

ref_edge(RefA, RefB) ->
  io_lib:format("    \"~p\" -> \"~p\"",[RefA,RefB]).

dref_edge(RefA, RefB) ->
  io_lib:format("    \"~p\":e -> \"~p\":e",[RefA,RefB]).

graph_close(#logger_state{graph_data = undefined}) -> ok;
graph_close(#logger_state{graph_data = {GraphFile, _, _}}) ->
  io:format(
    GraphFile,
    "  }~n"
    "}~n", []),
  file:close(GraphFile).

%%------------------------------------------------------------------------------

setup_symbolic_names(SymbolicNames, Processes) ->
  case SymbolicNames of
    false -> ok;
    true -> concuerror_callback:setup_logger(Processes)
  end.
