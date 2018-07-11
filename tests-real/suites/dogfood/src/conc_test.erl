-module(conc_test).

-export([test/0]).

test() ->
  %% Call some module_infos to ensure instrumentation.
  io_lib_pretty:module_info(),
  io:module_info(),
  epp:module_info(),
  concuerror:run(
    [ {entry_point,{conc_input,test,[]}}
    , {symbolic_names,false}
    %, {after_timeout, 1000}
    , no_output
    %, quiet
    , keep_going
    , {scheduling_bound, 0}
    , {scheduling_bound_type, delay}
    , {dpor, persistent}
    ]
   )
    , receive after infinity -> ok end
    .
