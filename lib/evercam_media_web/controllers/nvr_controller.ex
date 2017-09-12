defmodule EvercamMediaWeb.NVRController do
  use EvercamMediaWeb, :controller
  alias EvercamMediaWeb.ErrorView
  alias EvercamMedia.HikvisionNVR

  def get_info(conn, %{"id" => exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn)
    do
      ip = Camera.host(camera, "external")
      port = Camera.port(camera, "external", "http")
      cam_username = Camera.username(camera)
      cam_password = Camera.password(camera)
      url = camera.vendor_model.h264_url
      channel = url |> String.split("/channels/") |> List.last |> String.split("/") |> List.first

      stream_info = HikvisionNVR.get_stream_info(ip, port, cam_username, cam_password, channel)
      device_info = HikvisionNVR.get_device_info(ip, port, cam_username, cam_password)
      hdd_info = HikvisionNVR.get_hdd_info(ip, port, cam_username, cam_password)
      json(conn, %{stream_info: stream_info, device_info: device_info, hdd_info: hdd_info})
    end
  end

  def get_vh_info(conn, %{"id" => exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn)
    do
      ip = Camera.host(camera, "external")
      port = Camera.port(camera, "external", "http")
      cam_username = Camera.username(camera)
      cam_password = Camera.password(camera)
      url = camera.vendor_model.h264_url
      channel = url |> String.split("/channels/") |> List.last |> String.split("/") |> List.first

      vh_info = HikvisionNVR.get_vh_info(ip, port, cam_username, cam_password, channel)

      response =
        case Map.get(vh_info, :vh_port) do
          nil -> %{vh_info: vh_info, vh_stream_info: %{}, vh_device_info: %{}}
          "" -> %{vh_info: vh_info, vh_stream_info: %{}, vh_device_info: %{}}
          vh_port ->
            vh_stream_info = HikvisionNVR.get_stream_info(ip, vh_port, cam_username, cam_password, channel)
            vh_device_info = HikvisionNVR.get_device_info(ip, vh_port, cam_username, cam_password)
            %{vh_info: vh_info, vh_stream_info: vh_stream_info, vh_device_info: vh_device_info}
        end

      json(conn, response)
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
end
