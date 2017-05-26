defmodule EvercamMedia.Snapshot.Streamer do
  @moduledoc """
  TODO
  """

  use GenServer
  alias EvercamMedia.Util
  alias EvercamMedia.Snapshot.CamClient
  alias EvercamMedia.Snapshot.DBHandler
  alias EvercamMedia.Snapshot.Error
  alias EvercamMedia.Snapshot.StreamerSupervisor
  require Logger

  ################
  ## Client API ##
  ################

  @doc """
  Start the Snapshot streamer for a given camera.
  """
  def start_link(camera_exid) do
    streamer_id = String.to_atom("#{camera_exid}_streamer")
    GenServer.start_link(__MODULE__, camera_exid, name: streamer_id)
  end

  ######################
  ## Server Callbacks ##
  ######################

  @doc """
  Initialize the camera streamer
  """
  def init(camera_exid) do
    Process.send_after(self(), :tick, 0)
    {:ok, camera_exid}
  end

  @doc """
  Either stream a snapshot to subscribers or shut down streaming
  """
  def handle_info(:tick, nil), do: :noop
  def handle_info(:tick, camera_exid) do
    camera = Camera.get_full(camera_exid)
    cond do
      camera == nil ->
        Logger.debug "[#{camera_exid}] Shutting down streamer, camera doesn't exist"
        StreamerSupervisor.stop_streamer(camera_exid)
      camera.is_online && ConCache.get(:snapshot_error, camera_exid) > 0 ->
        Logger.debug "[#{camera_exid}] Checking ..."
        spawn fn -> stream(camera) end
      length(subscribers(camera_exid)) == 0 ->
        Logger.debug "[#{camera_exid}] Shutting down streamer, no subscribers"
        StreamerSupervisor.stop_streamer(camera_exid)
      Camera.recording?(camera) ->
        Logger.debug "[#{camera_exid}] Shutting down streamer, already streaming"
        StreamerSupervisor.stop_streamer(camera_exid)
      true ->
        Logger.debug "[#{camera_exid}] Streaming ..."
        spawn fn -> stream(camera) end
    end
    Process.send_after(self(), :tick, 1000)
    {:noreply, camera_exid}
  end

  @doc """
  Take care of unknown messages which otherwise would trigger function clause mismatch error.
  """
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def stream(camera) do
    timestamp = Calendar.DateTime.now_utc |> Calendar.DateTime.Format.unix
    response = camera |> construct_args |> CamClient.fetch_snapshot

    case response do
      {:ok, data} ->
        Util.broadcast_snapshot(camera.exid, data, timestamp)
        DBHandler.update_camera_status(camera.exid, timestamp, true)
      {:error, error} ->
        Error.parse(error) |> Error.handle(camera.exid, timestamp, error)
    end
  end

  def subscribers(camera_exid) do
    Phoenix.PubSub.Local.subscribers(EvercamMedia.PubSub, "cameras:#{camera_exid}", 0)
  end

  defp construct_args(camera) do
    %{
      url: Camera.snapshot_url(camera),
      vendor_exid: Camera.get_vendor_attr(camera, :exid),
      username: Camera.username(camera),
      password: Camera.password(camera)
    }
  end
end
