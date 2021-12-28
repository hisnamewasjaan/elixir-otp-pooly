defmodule Pooly.Server do
  use GenServer
  import Supervisor.Spec

  defmodule State do
    defstruct sup: nil,
              worker_sup: nil,
              size: nil,
              workers: nil,
              mfa: nil,
              monitors: nil
  end

  # API

  def start_link(sup, pool_config) do
    GenServer.start_link(__MODULE__, [sup, pool_config], name: __MODULE__)
  end

  def checkout do
    GenServer.call(__MODULE__, :checkout)
  end

  def checkin(worker_pid) do
    GenServer.cast(__MODULE__, {:checkin, worker_pid})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  # Callbacks

  def init([sup, pool_config]) when is_pid(sup) do
    IO.puts("Pooly.Server <#{inspect self()}> init with supervisor <#{inspect sup}>")
    monitors = :ets.new(:monitors, [:private])
    init(pool_config, %State{sup: sup, monitors: monitors})
  end

  def init([{:mfa, mfa} | rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  def init([{:size, size} | rest], state) do
    init(rest, %{state | size: size})
  end

  def init([_ | rest], state) do
    init(rest, state)
  end

  def init([], state) do
    send(self(), :start_worker_supervisor)
    IO.puts("Pooly Server <#{inspect self()}> init with state <#{inspect state}>")
    {:ok, state}
  end

  # starts worker-supervisor and pre-populates the workers
  def handle_info(:start_worker_supervisor, state = %{sup: sup, mfa: mfa, size: size}) do
    IO.puts("Pooly Server :start_worker_supervisor as a child of <#{inspect sup}>. State <#{inspect state}>")
    {:ok, worker_sup} = Supervisor.start_child(sup, supervisor_spec(mfa))
    workers = prepopulate(size, worker_sup)
    IO.puts("Pooly Server <#{inspect self()}> started worker_supervisor <#{inspect worker_sup}>")
    IO.puts("Pooly Server <#{inspect self()}> state is now <#{inspect state}>")
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  def handle_call(:checkout, {from_pid, _ref}, %{workers: workers, monitors: monitors} = state) do
    IO.puts("Handle :checkout from <#{inspect from_pid}>")
    case workers do
      [worker | rest] ->
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}
      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {length(workers), :ets.info(monitors, :size)}, state}
  end

  def handle_cast({:checkin, worker}, %{workers: workers, monitors: monitors} = state) do
    IO.puts("Handle :checkin of worker <#{inspect worker}>")
    case :ets.lookup(monitors, worker) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        {:npreply, %{state | workers: [pid | workers]}}
      [] ->
        {:noreply, state}
    end
  end

  # private funcs

  # worker-supervisor spec
  defp supervisor_spec(mfa) do
    opts = [restart: :temporary]
    Supervisor.Spec.supervisor(Pooly.WorkerSupervisor, [mfa], opts)
  end

  defp prepopulate(size, sup) do
    prepopulate(size, sup, [])
  end

  defp prepopulate(size, _sup, workers) when size < 1 do
    workers
  end

  defp prepopulate(size, sup, workers) do
    prepopulate(size - 1, sup, [new_worker(sup) | workers])
  end

  defp new_worker(sup) do
    {:ok, worker} = Supervisor.start_child(sup, [[]])
    worker
  end

end
