%%% @private
-module(concuerror_dependencies).

-export([ dependent/3
        , dependent_safe/2
        , explain_error/1
        ]).

-export_type([assume_racing_opt/0]).

%%------------------------------------------------------------------------------

-include("concuerror.hrl").

-type assume_racing_opt() :: {boolean(), concuerror_logger:logger() | 'ignore'}.
-type dep_ret() :: boolean() | 'irreversible' | {'true', message_id()}.

%%------------------------------------------------------------------------------

-spec dependent(event(), event(), assume_racing_opt()) -> dep_ret().

dependent(#event{event_info = Info1} = Event1,
          #event{event_info = Info2} = Event2,
          AssumeRacing) ->
  try
    case dependent(Info1, Info2) of
      false ->
        #event{special = Special1} = Event1,
        #event{special = Special2} = Event2,
        
        M1 = [M || {message_delivered, M} <- Special1],
        M2 = [M || {message_delivered, M} <- Special2],
        first_non_false_dep([Info1|M1], M2, [Info2|M2]);
      Else -> Else
    end
  catch
    throw:irreversible -> irreversible;
    error:function_clause ->
      case AssumeRacing of
        {true, ignore} -> true;
        {true, Logger} ->
          Explanation = show_undefined_dependency(Info1, Info2),
          Msg =
            io_lib:format(
              "~s~n"
              " Concuerror treats such pairs as racing (--assume_racing)."
              " (No other such warnings will appear)~n", [Explanation]),
          ?unique(Logger, ?lwarning, Msg, []),
          true;
        {false, _} ->
          ?crash({undefined_dependency, Info1, Info2, []})
      end
  end.

first_non_false_dep([], _, _) -> false;
first_non_false_dep([_|R], [], I2) ->
  first_non_false_dep(R, I2, I2);
first_non_false_dep([I1H|_] = I1, [I2H|R], I2) ->
  case dependent(I1H, I2H) of
    false -> first_non_false_dep(I1, R, I2);
    Else -> Else
  end.

-spec dependent_safe(event(), event()) -> dep_ret().

dependent_safe(E1, E2) ->
  dependent(E1, E2, {true, ignore}).

-spec explain_error(term()) -> string().

explain_error(Term) ->
  io_lib:format(
    "Generic Error: ~p ~p~n",
    [?MODULE, Term]).

show_undefined_dependency(A, B) ->
  io_lib:format(
    "The following pair of instructions is not explicitly marked as non-racing"
    " in Concuerror's internals:~n"
    "  1) ~s~n  2) ~s~n"
    " Please notify the developers to add info about this pair.",
    [concuerror_io_lib:pretty_s(#event{event_info = I}, 10) || I <- [A,B]]).

%%------------------------------------------------------------------------------

dependent(A, B) ->
  concuerror_dependencies_legacy:dependent(A, B).

