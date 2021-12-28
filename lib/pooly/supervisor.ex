defmodule Pooly.Supervisor do
  use Supervisor

  def start_link(pool_config) do
    Supervisor.start_link(__MODULE__, pool_config)
  end

  def init(pool_config) do
    IO.puts("Pooly.Supervisor <#{inspect self()}> init")
    children = [
      worker(Pooly.Server, [self(), pool_config])
    ]

    opts = [strategy: :one_for_all]
    IO.puts("Pooly.Supervisor calling supervise with children <#{inspect children}>")
    supervise(children, opts)
  end

end
