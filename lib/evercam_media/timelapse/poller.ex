defmodule EvercamMedia.Timelapse.Poller do
  @moduledoc """
  Provides functions and workers for creating timelapse

  """

  use GenServer
  require Logger
  alias EvercamMedia.Timelapse.Timelapser

  ################
  ## Client API ##
  ################

  @doc """
  Start a poller for timelapse worker.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Restart the poller for the timelapse that creates timelapse in specific time
  as defined in the args passed to the timelapse server.
  """
  def start_timer(cam_server) do
    GenServer.call(cam_server, :restart_timelapse_timer)
  end

  @doc """
  Stop the poller for the timelapse.
  """
  def stop_timer(cam_server) do
    GenServer.call(cam_server, :stop_timelapse_timer)
  end

  @doc """
  Get the configuration of the timelapse worker.
  """
  def get_config(cam_server) do
    GenServer.call(cam_server, :get_poller_config)
  end

  @doc """
  Update the configuration of the timelapse worker
  """
  def update_config(cam_server, config) do
    GenServer.cast(cam_server, {:update_timelapse_config, config})
  end

  ######################
  ## Server Callbacks ##
  ######################

  @doc """
  Initialize the timelapse server
  """
  def init(args) do
    args = Map.merge args, %{
      timer: start_timer(args.config.sleep, :poll)
    }
    {:ok, args}
  end

  @doc """
  Server callback for restarting timelapse poller
  """
  def handle_call(:restart_timelapse_timer, _from, state) do
    {:reply, nil, state}
  end

  @doc """
  Server callback for getting timelapse poller state
  """
  def handle_call(:get_poller_config, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Server callback for stopping timelapse poller
  """
  def handle_call(:stop_timelapse_timer, _from, state) do
    {:reply, nil, state}
  end

  def handle_cast({:update_timelapse_config, new_config}, state) do
    {:ok, timer} = Map.fetch(state, :timer)
    :erlang.cancel_timer(timer)
    new_timer = start_timer(new_config.config.sleep, :poll)
    new_config = Map.merge new_config, %{
      timer: new_timer
    }
    {:noreply, new_config}
  end

  @doc """
  Server callback for polling
  """
  def handle_info(:poll, state) do
    {:ok, timer} = Map.fetch(state, :timer)
    :erlang.cancel_timer(timer)
    case Timelapse.scheduled_now?(state.config.timezone, state.config.from_datetime, state.config.to_datetime, state.config.date_always, state.config.time_always) do
      {:ok, true} ->
        Logger.debug "Polling timelapse: #{state.name} for timelapse"
        timestamp = Calendar.DateTime.now!("UTC") |> Calendar.DateTime.Format.unix
        send_request(state.config.status, state, timestamp)
      {:ok, false} ->
        Logger.debug "Not Scheduled. Skip timelapse for #{inspect state.name}"
    end

    timer = start_timer(state.config.sleep, :poll)
    {:noreply, Map.put(state, :timer, timer)}
  end

  @doc """
  Take care of unknown messages which otherwise would trigger function clause mismatch error.
  """
  def handle_info(msg, state) do
    Logger.info "[handle_info] [#{msg}] [#{state.name}] [unknown messages]"
    {:noreply, state}
  end

  #######################
  ## Private functions ##
  #######################

  defp send_request(3, _state, _timestamp), do: :noop
  defp send_request(_status, state, timestamp) do
    Timelapser.get_snapshot(state.name, {:poll, timestamp})
  end

  defp start_timer(sleep, message) do
    Process.send_after(self, message, sleep)
  end
end
