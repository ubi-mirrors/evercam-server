defmodule EvercamMedia.Snapshot.DBHandler do
  @moduledoc """
  This module should ideally delegate all the updates to be made to the database
  on various events to another module.

  Right now, this is a extracted and slightly modified from the previous version of
  worker.

  These are the list of tasks for the db handler
    * Create an entry in the snapshots table for each retrived snapshots
    * Update the CameraActivity table whenever there is a change in the camera status
    * Update the status and last_polled_at values of Camera table
    * Update the thumbnail_url of the Camera table - This was done in the previous
    version and not now. This update can be avoided if thumbnails can be dynamically
    served.
  """
  use GenStage
  require Logger
  alias EvercamMedia.Repo
  alias EvercamMedia.SnapshotRepo
  alias EvercamMedia.Util
  alias EvercamMedia.Snapshot.Error
  alias EvercamMedia.Snapshot.WorkerSupervisor
  alias EvercamMedia.Snapshot.Storage

  def init(:ok) do
    {:producer_consumer, :ok}
  end

  def handle_info({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    Logger.debug "[#{camera_exid}] [snapshot_success]"
    spawn fn -> Storage.save(camera_exid, timestamp, image, "Evercam Proxy") end
    spawn fn -> update_camera_status("#{camera_exid}", timestamp, true) end
    Util.broadcast_snapshot(camera_exid, image, timestamp)
    {:noreply, [], state}
  end

  def handle_info({:snapshot_error, data}, state) do
    try do
      {camera_exid, timestamp, error} = data
      error |> Error.parse |> Error.handle(camera_exid, timestamp, error)
    catch _type, error ->
      Util.error_handler(error)
    end
    {:noreply, [], state}
  end

  def handle_info(_, state) do
    Logger.debug "handle empty"
    {:noreply, [], state}
  end

  def update_camera_status(camera_exid, timestamp, status, error_code \\ "generic", error_weight \\ 0)

  def update_camera_status("", _timestamp, _status, _error_code, _error_weight), do: :noop
  def update_camera_status(camera_exid, timestamp, status, error_code, error_weight) do
    camera = Camera.get_full(camera_exid)
    old_error_total = ConCache.dirty_get_or_store(:snapshot_error, camera.exid, fn() -> 0 end)
    error_total = old_error_total + error_weight
    cond do
      status == true && camera.is_online != status ->
        change_camera_status(camera, timestamp, true)
        ConCache.dirty_put(:snapshot_error, camera.exid, 0)
        Logger.debug "[#{camera_exid}] [update_status] [online]"
      status == true ->
        ConCache.dirty_put(:snapshot_error, camera.exid, 0)
      status == false && camera.is_online != status && error_total >= 100 ->
        change_camera_status(camera, timestamp, false, error_code)
        Logger.info "[#{camera_exid}] [update_status] [offline] [#{error_code}]"
      status == false && camera.is_online != status ->
        ConCache.dirty_put(:snapshot_error, camera.exid, error_total)
        Logger.info "[#{camera_exid}] [update_status] [error] [#{error_code}] [#{error_total}]"
        pause_camera_requests(camera, error_code, rem(error_total, 5))
      status == false ->
        ConCache.dirty_put(:snapshot_error, camera.exid, error_total)
      true -> :noop
    end
    Camera.get_full(camera_exid)
  end

  defp pause_camera_requests(camera, _error_code, 0), do: do_pause_camera(camera, 5000)
  defp pause_camera_requests(_camera, _error_code, _reminder), do: :noop

  defp do_pause_camera(camera, pause_seconds, is_pause \\ true) do
    Logger.debug("Pause camera requests for #{camera.exid}")
    camera.exid
    |> String.to_atom
    |> Process.whereis
    |> WorkerSupervisor.pause_worker(camera, is_pause, pause_seconds)
  end

  def change_camera_status(camera, timestamp, status, error_code \\ nil) do
    do_pause_camera(camera, 20000)
    try do
      datetime =
        timestamp
        |> Calendar.DateTime.Parse.unix!
        |> Calendar.DateTime.to_erl
        |> Ecto.DateTime.cast!
      params = construct_camera(datetime, status, camera.is_online == status)
      changeset = Camera.changeset(camera, params)
      camera = Repo.update!(changeset)
      log_camera_status(camera, status, datetime, error_code)
      broadcast_change_to_users(camera)
      Camera.invalidate_camera(camera)
    catch _type, error ->
      Util.error_handler(error)
    end
    do_pause_camera(camera, 5000, false)
  end

  def broadcast_change_to_users(camera) do
    User.with_access_to(camera)
    |> Enum.each(fn(user) -> Util.broadcast_camera_status(camera.exid, camera.is_online, user.username) end)
  end

  def log_camera_status(camera, true, datetime, nil), do: do_log_camera_status(camera, "online", datetime)
  def log_camera_status(camera, false, datetime, error_code), do: do_log_camera_status(camera, "offline", datetime, %{reason: error_code})

  defp do_log_camera_status(camera, status, datetime, extra \\ nil) do
    spawn fn ->
      case ConCache.get(:current_camera_status, camera.exid) |> declare_camera_status(camera) |> humanize_status == status do
        false ->
          ConCache.dirty_put(:current_camera_status, camera.exid, camera.is_online)
          parameters = %{camera_id: camera.id, camera_exid: camera.exid, action: status, done_at: datetime, extra: extra}
          changeset = CameraActivity.changeset(%CameraActivity{}, parameters)
          SnapshotRepo.insert(changeset)
          send_notification(status, camera, camera.alert_emails)
        true -> ConCache.dirty_put(:current_camera_status, camera.exid, camera.is_online)
      end
    end
  end

  defp declare_camera_status(nil, camera) do
    case camera.is_online do
      true -> false
      false -> true
    end
  end
  defp declare_camera_status(status, _camera), do: status

  defp humanize_status(true), do: "online"
  defp humanize_status(false), do: "offline"

  defp send_notification(_status, _camera, alert_emails) when alert_emails in [nil, ""], do: :noop
  defp send_notification(status, camera, _alert_emails) do
    EvercamMedia.UserMailer.camera_status(status, camera.owner, camera)
  end

  defp construct_camera(datetime, online_status, online_status_unchanged)
  defp construct_camera(datetime, false, false) do
    %{last_polled_at: datetime, is_online: false, last_online_at: datetime}
  end
  defp construct_camera(datetime, status, _) do
    %{last_polled_at: datetime, is_online: status}
  end
end
