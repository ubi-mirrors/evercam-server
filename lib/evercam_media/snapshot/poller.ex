defmodule EvercamMedia.Snapshot.Poller do
  @moduledoc """
  Provides functions and workers for getting snapshots from the camera

  Functions can be called from other places to get snapshots manually.
  """

  use GenServer
  require Logger
  alias EvercamMedia.Snapshot.Worker
  import EvercamMedia.Schedule, only: [scheduled_now?: 3]

  ################
  ## Client API ##
  ################

  @doc """
  Start a poller for camera worker.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Restart the poller for the camera that takes snapshot in frequent interval
  as defined in the args passed to the camera server.
  """
  def start_timer(cam_server) do
    GenServer.call(cam_server, :restart_camera_timer)
  end

  @doc """
  Stop the poller for the camera.
  """
  def stop_timer(cam_server) do
    GenServer.call(cam_server, :stop_camera_timer)
  end

  @doc """
  Get the configuration of the camera worker.
  """
  def get_config(cam_server) do
    GenServer.call(cam_server, :get_poller_config)
  end

  @doc """
  Update the configuration of the camera worker
  """
  def update_config(cam_server, config) do
    GenServer.cast(cam_server, {:update_camera_config, config})
  end


  ######################
  ## Server Callbacks ##
  ######################

  @doc """
  Initialize the camera server
  """
  def init(args) do
    args = Map.merge args, %{
      timer: start_timer(args.config.sleep, :poll, args.config.is_paused, args.config.pause_seconds)
    }
    {:ok, args}
  end

  @doc """
  Server callback for restarting camera poller
  """
  def handle_call(:restart_camera_timer, _from, state) do
    {:reply, nil, state}
  end

  @doc """
  Server callback for getting camera poller state
  """
  def handle_call(:get_poller_config, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Server callback for stopping camera poller
  """
  def handle_call(:stop_camera_timer, _from, state) do
    {:reply, nil, state}
  end

  def handle_cast({:update_camera_config, new_config}, state) do
    {:ok, timer} = Map.fetch(state, :timer)
    :erlang.cancel_timer(timer)
    new_timer = start_timer(new_config.config.sleep, :poll, new_config.config.is_paused, new_config.config.pause_seconds)
    new_config = Map.merge new_config, %{
      timer: new_timer
    }
    {:noreply, new_config}
  end

  @doc """
  Server callback for polling
  """
  def handle_info(:poll, state) do
    state = put_in(state, [:config, :is_paused], false)
    {:ok, timer} = Map.fetch(state, :timer)
    :erlang.cancel_timer(timer)
    timestamp = Calendar.DateTime.now!("UTC") |> Calendar.DateTime.Format.unix
    case scheduled_now?(state.config.schedule, state.config.recording, state.config.timezone) do
      {:ok, true} ->
        Logger.debug "Polling camera: #{state.name} for snapshot"
        Worker.get_snapshot(state.name, {:poll, timestamp})
      {:ok, false} ->
        Logger.debug "Not Scheduled. Skip fetching snapshot from #{inspect state.name}"
      {:error, _message} ->
        Logger.error "Error getting scheduler information for #{inspect state.name}"
    end
    timer = start_timer(state.config.sleep, :poll, state.config.is_paused, state.config.pause_seconds)
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

  defp start_timer(sleep, message, false, _pause_sleep) do
    Process.send_after(self(), message, sleep)
  end

  defp start_timer(_sleep, message, true, pause_sleep) do
    Process.send_after(self(), message, pause_sleep)
  end
end
