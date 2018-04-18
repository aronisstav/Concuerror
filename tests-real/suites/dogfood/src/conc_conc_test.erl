-module(conc_conc_test).

-export([test/0]).

-concuerror_options(
   [
    {timeout, 5000}
   , {after_timeout, 1000}
   , {symbolic_names, false}
   , {print_depth, 50}
   ]).

test() ->
  %% Call some module_infos to ensure instrumentation.
  io_lib_pretty:module_info(),
  io:module_info(),
  epp:module_info(),
  concuerror_dependencies:module_info(),
  concuerror:run(
    [
      {entry_point,{conc_test,test,[]}}
    , {symbolic_names,false}
    , {after_timeout, 1000}
    , no_output
    , quiet
    ]
   )
    %, receive after infinity -> ok end
    .
