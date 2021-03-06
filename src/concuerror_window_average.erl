%%% @private
%%% @doc
%%% This module provides functions for calculating a running
%%% window average of numerical values.

-module(concuerror_window_average).

-export([init/2, update/2]).

-export_type([average/0]).

%%------------------------------------------------------------------------------

-include("concuerror.hrl").

-type queue() :: queue:queue().

-record(average, {
          queue  :: queue(),
          sum    :: number(),
          window :: pos_integer()
         }).

-opaque average() :: #average{}.

%%------------------------------------------------------------------------------

-spec init(number(), pos_integer()) -> average().

init(Initial, Window) ->
  Queue = queue:from_list([Initial || _ <- lists:seq(1, Window)]),
  Sum = Initial * Window,
  #average{
     queue = Queue,
     sum = Sum,
     window = Window
    }.

%%------------------------------------------------------------------------------

-spec update(number(), average()) -> {float(), average()}.

update(Sample, Average) ->
  #average{
     queue = Queue,
     sum = Sum,
     window = Window
    } = Average,
  {{value, Out}, OutQueue} = queue:out(Queue),
  NewQueue = queue:in(Sample, OutQueue),
  NewSum = Sum + Sample - Out,
  NewAverage =
    Average#average{
      queue = NewQueue,
      sum = NewSum
     },
  {NewSum/Window, NewAverage}.
