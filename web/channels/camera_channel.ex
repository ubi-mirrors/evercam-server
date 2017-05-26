defmodule EvercamMedia.CameraChannel do
  use Phoenix.Channel
  alias EvercamMedia.Snapshot.StreamerSupervisor
  alias EvercamMedia.Util

  def join("cameras:" <> camera_exid, _auth_msg, socket) do
    camera = Camera.get_full(camera_exid)
    user = Util.deep_get(socket, [:assigns, :current_user], nil)

    if Permission.Camera.can_snapshot?(user, camera) do
      send(self(), {:after_join, camera_exid})
      {:ok, socket}
    else
      {:error, "Unauthorized."}
    end
  end

  def handle_info({:after_join, camera_exid}, socket) do
    StreamerSupervisor.start_streamer(camera_exid)
    {:noreply, socket}
  end
end
