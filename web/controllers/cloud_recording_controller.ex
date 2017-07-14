defmodule EvercamMedia.CloudRecordingController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.ErrorView
  alias EvercamMedia.Snapshot.WorkerSupervisor
  import EvercamMedia.Validation.CloudRecording

  def show(conn, %{"id" => exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn),
         do: camera.cloud_recordings |> render_cloud_recording(conn)
  end

  def create(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn),
         :ok <- validate_params(params) |> ensure_params(conn)
    do
      cr_params = %{
        camera_id: camera.id,
        frequency: params["frequency"],
        storage_duration: params["storage_duration"],
        status: params["status"],
        schedule: get_json(params["schedule"])
      }

      old_cloud_recording = camera.cloud_recordings || %CloudRecording{}
      action_log = get_action_log(camera.cloud_recordings)
      case old_cloud_recording |> CloudRecording.changeset(cr_params) |> Repo.insert_or_update do
        {:ok, cloud_recording} ->
          camera = camera |> Repo.preload(:cloud_recordings, force: true)
          Camera.invalidate_camera(camera)
          exid
          |> String.to_atom
          |> Process.whereis
          |> WorkerSupervisor.update_worker(camera)

          CameraActivity.log_activity(current_user, camera, "cloud recordings #{action_log}",
            %{
              ip: user_request_ip(conn),
              cr_settings: %{
                old: set_settings(old_cloud_recording),
                new: set_settings(cloud_recording)
                },
              }
          )
          send_email_on_cr_change(Application.get_env(:evercam_media, :run_spawn), current_user, camera, cloud_recording, old_cloud_recording, user_request_ip(conn))
          conn
          |> render("cloud_recording.json", %{cloud_recording: cloud_recording})
        {:error, changeset} ->
          render_error(conn, 400, changeset)
      end
    end
  end

  def hikvision_nvr(conn, %{"id" => exid, "starttime" => starttime, "endtime" => endtime}) do
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn)
    do
      ip = Camera.host(camera, "external")
      port = Camera.port(camera, "external", "rtsp")
      cam_username = Camera.username(camera)
      cam_password = Camera.password(camera)
      url = camera.vendor_model.h264_url
      channel = url |> String.split("/channels/") |> List.last |> String.split("/") |> List.first
      case EvercamMedia.HikvisionNVR.publish_stream_from_rtsp(camera.exid, ip, port, cam_username, cam_password, channel, convert_timestamp(starttime), convert_timestamp(endtime)) do
        {:ok} -> json(conn, %{message: "Streaming started."})
        {:error} -> render_error(conn, 404, "No recordings found")
      end
    end
  end

  defp convert_timestamp(timestamp) do
    timestamp
    |> String.to_integer
    |> Calendar.DateTime.Parse.unix!
    |> Calendar.Strftime.strftime!("%Y%m%dT%H%M%SZ")
  end

  defp set_settings(cloud_recording) do
    case cloud_recording.camera_id do
      nil -> nil
      _ ->
        %{status: cloud_recording.status, storage_duration: cloud_recording.storage_duration, frequency: cloud_recording.frequency, schedule: cloud_recording.schedule}
    end
  end

  defp send_email_on_cr_change(false, _current_user, _camera, _cloud_recording, _old_cloud_recording, _user_request_ip), do: :noop
  defp send_email_on_cr_change(true, current_user, camera, cloud_recording, old_cloud_recording, user_request_ip) do
    try do
      Task.start(fn ->
        EvercamMedia.UserMailer.cr_settings_changed(current_user, camera, cloud_recording, old_cloud_recording, user_request_ip)
      end)
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  defp ensure_camera_exists(nil, exid, conn) do
    conn
    |> put_status(404)
    |> render(ErrorView, "error.json", %{message: "Camera '#{exid}' not found!"})
  end
  defp ensure_camera_exists(_camera, _id, _conn), do: :ok

  defp ensure_can_edit(current_user, camera, conn) do
    if Permission.Camera.can_edit?(current_user, camera) do
      :ok
    else
      conn
      |> put_status(403)
      |> render(ErrorView, "error.json", %{message: "You don't have sufficient rights for this."})
    end
  end

  defp ensure_params(:ok, _conn), do: :ok
  defp ensure_params({:invalid, message}, conn), do: json(conn, %{error: message})

  defp get_json(schedule) do
    case Poison.decode(schedule) do
      {:ok, json} -> json
    end
  end

  defp render_cloud_recording(nil, conn), do: conn |> render("show.json", %{cloud_recording: []})
  defp render_cloud_recording(cl, conn), do: conn |> render("cloud_recording.json", %{cloud_recording: cl})

  defp get_action_log(nil), do: "created"
  defp get_action_log(_cloud_recording), do: "updated"
end
