defmodule EvercamMediaWeb.MotionDetectionController do
  use EvercamMedia.Web, :controller

  def show(conn, %{"id" => camera_exid}) do
    caller = conn.assigns[:current_user]
    camera = Camera.get_full(camera_exid)

    with :ok <- camera_exists(camera),
         :ok <- ensure_authorized(caller, camera)
    do
      render(conn, "show.json", %{motion_detection: camera.motion_detections})
    else
      {:error, :camera_doesnt_exist} ->
        render_error(conn, 404, "The #{camera_exid} camera does not exist.")
      {:error, :forbidden} ->
        render_error(conn, 403, "Forbidden.")
    end
  end

  defp camera_exists(nil), do: {:error, :camera_doesnt_exist}
  defp camera_exists(_camera), do: :ok

  defp ensure_authorized(user, camera) do
    if Permission.Camera.can_view?(user, camera), do: :ok, else: {:error, :forbidden}
  end
end
