defmodule EvercamMedia.CameraShareView do
  use EvercamMedia.Web, :view
  alias EvercamMedia.Util

  def render("index.json", %{camera_shares: camera_shares, camera: camera, user: user}) do
    shares_json = %{shares: render_many(camera_shares, __MODULE__, "camera_share.json")}
    if Permission.Camera.can_edit?(user, camera) do
      shares_json |> Map.merge(privileged_camera_attributes(camera))
    else
      shares_json
    end
  end

  def render("show.json", %{camera_share: camera_share}) do
    %{shares: render_many([camera_share], __MODULE__, "camera_share.json")}
  end

  def render("camera_share.json", %{camera_share: camera_share}) do
    %{
      id: camera_share.id,
      kind: camera_share.kind,
      email: Util.deep_get(camera_share, [:user, :email], ""),
      camera_id: camera_share.camera.exid,
      fullname: User.get_fullname(camera_share.user),
      sharer_name: User.get_fullname(camera_share.sharer),
      sharer_id: Util.deep_get(camera_share, [:sharer, :username], ""),
      sharer_email: Util.deep_get(camera_share, [:sharer, :email], ""),
      user_id: Util.deep_get(camera_share, [:user, :username], ""),
      rights: CameraShare.get_rights(camera_share.kind, camera_share.user, camera_share.camera),
    }
  end

  defp privileged_camera_attributes(camera) do
    %{
      owner: %{
        email: camera.owner.email,
        username: camera.owner.username,
        fullname: User.get_fullname(camera.owner),
      }
    }
  end
end
