%% -*- erlang-indent-level: 2 -*-

-module(concuerror_generator).

%% Interface to concuerror.erl
-export([start/1, stop/1]).

-ifdef(BEFORE_OTP_17).
-type process_queue() :: queue().
-else.
-type process_queue() :: queue:queue(pid()).
-endif.

-record(generator_state, {
          max_processes :: non_neg_integer(),
          process_queue :: process_queue()
         }).

-spec start(concuerror_options:options()) -> pid().

start(Options) ->
  Parent = self(),
  Fun =
    fun() ->
        State = initialize_generator(Options),
        Parent ! process_gen_ready,
        generator_loop(State)
    end,
  P = spawn_link(Fun),
  receive
    process_gen_ready -> P
  end.

initialize_generator(Options) ->
  MaxProcesses = ?opt(number_of_processes, Options),
  Fun = fun() -> idle_process() end,
  AvailableProcesses = [spawn(Fun) || _ <- lists:seq(1, TotalProcesses)],
  queue:from_list(AvailableProcesses),
  #generator_state{
     max_processes = MaxProcesses,
     process_queue = AvailableProcesses
    }.

idle_process() ->
  receive
    {wakeup, Info} ->
      concuerror_callback:process_top_loop(Info)
  end.

generator_loop(State) ->
  #generator_state{process_queue = ProcessQueue} = State,
  receive
    {Scheduler, get_new_process, Info} ->
      case queue:out(ProcessQueue) of
	{empty, ProcessQueue} ->
	  Scheduler ! {process_limit_exceeded, State#generator_state.max_processes},
	  generator_loop(State);
	{{value, Process}, NewProcessQueue} ->
	  Process ! {wakeup, Info},
	  Scheduler ! {new_process, Process},
	  generator_loop(State#generator_state{process_queue = NewProcessQueue})
      end;
    {Pid, cleanup} ->
      _ = [exit(IdleProcess, kill) || IdleProcess <- queue:to_list(ProcessQueue)],
      Pid ! done
  end.

-spec stop(pid()) -> ok.

stop(ProcessGenerator) ->
  ProcessGenerator ! {self(), cleanup},
  receive
    done ->
      ok
  end.
