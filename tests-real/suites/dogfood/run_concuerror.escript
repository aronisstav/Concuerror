#!/usr/bin/env escript
%% -*- erlang-indent-level: 2 -*-
%%! +S1 -noshell -pa . -pa ebin

main(_Args) ->
  concuerror:run(
    [ {module, conc_test}
    , {graph, "graph.dot"}
    , {depth_bound, 10000}
    , show_races
    , keep_going
    , {after_timeout, 100}
    ]).
