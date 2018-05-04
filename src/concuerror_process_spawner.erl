-module(concuerror_process_spawner).

%% Interface to concuerror.erl
-export([start/1, stop/1, spawn_link/2]).
-export([explain_error/1]).

-include("concuerror.hrl").

-ifdef(BEFORE_OTP_17).
-type process_queue() :: queue().
-else.
-type process_queue() :: queue:queue(pid()).
-endif.

-record(spawner_state, {
          max_processes :: non_neg_integer(),
          process_queue :: process_queue()
         }).

-spec start(concuerror_options:options()) -> pid().

start(Options) ->
  Parent = self(),
  Fun =
    fun() ->
        State = initialize_spawner(Options),
        Parent ! process_gen_ready,
        spawner_loop(State)
    end,
  P = spawn_link(Fun),
  receive
    process_gen_ready -> P
  end.

initialize_spawner(Options) ->
  MaxProcesses = ?opt(max_processes, Options),
  Fun = fun() -> wait_activation() end,
  AvailableProcesses = [spawn(Fun) || _ <- lists:seq(1, MaxProcesses)],
  #spawner_state{
     max_processes = MaxProcesses,
     process_queue = queue:from_list(AvailableProcesses)
    }.

wait_activation() ->
  receive
    {activate, {Module, Name, Args}} ->
      erlang:apply(Module, Name, Args);
    stop -> ok
  end.

spawner_loop(State) ->
  #spawner_state{process_queue = ProcessQueue} = State,
  receive
    {Caller, get_new_process, MFArgs} ->
      case queue:out(ProcessQueue) of
	{empty, ProcessQueue} ->
	  Caller ! {process_limit_exceeded, State#spawner_state.max_processes},
	  spawner_loop(State);
	{{value, Process}, NewProcessQueue} ->
	  Process ! {activate, MFArgs},
	  Caller ! {new_process, Process},
	  spawner_loop(State#spawner_state{process_queue = NewProcessQueue})
      end;
    {Pid, cleanup} ->
      _ = [IdleProcess ! stop || IdleProcess <- queue:to_list(ProcessQueue)],
      Pid ! done
  end.

-spec spawn_link(pid(), {module(), atom(), [term()]}) -> pid().

spawn_link(ProcessSpawner, MFArgs) ->
  ProcessSpawner ! {self(), get_new_process, MFArgs},
  receive
    {new_process, Pid} ->
      link(Pid),
      Pid;
    {process_limit_exceeded, MaxProcesses} ->
      ?crash({process_limit_exceeded, MaxProcesses})
  end.

-spec stop(pid()) -> ok.

stop(ProcessSpawner) ->
  ProcessSpawner ! {self(), cleanup},
  receive
    done ->
      ok
  end.

-spec explain_error(term()) -> string().

explain_error({process_limit_exceeded, MaxProcesses}) ->
  io_lib:format(
    "Your test is using more than ~w processes (--max_processes)."
    " You can specify a higher limit, but consider using fewer processes.",
    [MaxProcesses]).
