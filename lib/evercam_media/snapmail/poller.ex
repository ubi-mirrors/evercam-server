defmodule EvercamMedia.Snapmail.Poller do
  @moduledoc """
  Provides functions and workers for sending snapmails

  """

  use GenServer
  require Logger
  alias EvercamMedia.Snapmail.Snapmailer

  ################
  ## Client API ##
  ################

  @doc """
  Start a poller for snapmail worker.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Restart the poller for the snapmail that sends snapmail in specific time
  as defined in the args passed to the snapmail server.
  """
  def start_timer(cam_server) do
    GenServer.call(cam_server, :restart_snapmail_timer)
  end

  @doc """
  Stop the poller for the snapmail.
  """
  def stop_timer(cam_server) do
    GenServer.call(cam_server, :stop_snapmail_timer)
  end

  @doc """
  Get the configuration of the snapmail worker.
  """
  def get_config(cam_server) do
    GenServer.call(cam_server, :get_poller_config)
  end

  @doc """
  Update the configuration of the snapmail worker
  """
  def update_config(cam_server, config) do
    GenServer.cast(cam_server, {:update_snapmail_config, config})
  end


  ######################
  ## Server Callbacks ##
  ######################

  @doc """
  Initialize the snapmail server
  """
  def init(args) do
    args = Map.merge args, %{
      timer: start_timer(args.config.sleep, :poll)
    }
    {:ok, args}
  end

  @doc """
  Server callback for restarting snapmail poller
  """
  def handle_call(:restart_snapmail_timer, _from, state) do
    {:reply, nil, state}
  end

  @doc """
  Server callback for getting snapmail poller state
  """
  def handle_call(:get_poller_config, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Server callback for stopping snapmail poller
  """
  def handle_call(:stop_snapmail_timer, _from, state) do
    {:reply, nil, state}
  end

  def handle_cast({:update_snapmail_config, new_config}, state) do
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
    case Snapmail.scheduled_now?(state.config.days, state.config.timezone) do
      {:ok, true} ->
        Logger.debug "Polling snapmail: #{state.name} for snapmail"
        timestamp = Calendar.DateTime.now!("UTC") |> Calendar.DateTime.Format.unix
        send_mail(state.config.is_paused, state.name, timestamp, state.config.recipients)
      {:ok, false} ->
        Logger.debug "Not Scheduled. Skip sending snapmail for #{inspect state.name}"
    end
    sleep = Snapmail.sleep(state.config.notify_time, state.config.timezone)
    timer = start_timer(sleep, :poll)
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

  defp start_timer(sleep, message) do
    Process.send_after(self(), message, sleep)
  end

  defp send_mail(true, _name, _timestamp, _recipients), do: :noop
  defp send_mail(false, _name, _timestamp, recipients) when recipients in [nil, ""], do: :noop
  defp send_mail(false, name, timestamp, _recipients) do
    Snapmailer.get_snapshot(name, {:poll, timestamp})
  end
end
