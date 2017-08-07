defmodule EvercamMediaWeb.CameraShareRequestView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{camera_share_requests: camera_share_requests}) do
    %{share_requests: render_many(camera_share_requests, __MODULE__, "camera_share_request.json")}
  end

  def render("show.json", %{camera_share_requests: camera_share_request}) do
    %{share_requests: render_many([camera_share_request], __MODULE__, "camera_share_request.json")}
  end

  def render("camera_share_request.json", %{camera_share_request: camera_share_request}) do
    %{
      id: camera_share_request.key,
      email: camera_share_request.email,
      rights: camera_share_request.rights,
      camera_id: camera_share_request.camera.exid,
      sharer_name: User.get_fullname(camera_share_request.user),
      user_id: Util.deep_get(camera_share_request, [:user, :username], ""),
      sharer_email: Util.deep_get(camera_share_request, [:user, :email], ""),
    }
  end
end
