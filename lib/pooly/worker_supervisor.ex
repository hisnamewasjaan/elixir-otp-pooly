defmodule Pooly.WorkerSupervisor do
  use Supervisor

  def start_link({_, _, _} = mod_fun_args) do
    Supervisor.start_link(__MODULE__, mod_fun_args)
  end

  #############
  # Callbacks #
  #############

  def init({mod, fun, args}) do
    IO.puts("Pooly.WorkerSupervisor init")
    worker_opts = [
      restart: :permanent,
      function: fun
    ]

    # create child specification
    children = [Supervisor.Spec.worker(mod, args, worker_opts)]
    opts = [
      strategy: :simple_one_for_one,
      max_restarts: 5,
      max_seconds: 5
    ]

    IO.puts("Pooly.WorkerSupervisor calling supervise with children <#{inspect children}>")

    # create supervisor specification
    Supervisor.Spec.supervise(children, opts)
  end

end
