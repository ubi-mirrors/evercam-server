defmodule EvercamMediaWeb.ArchiveView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{archives: archives}) do
    %{archives: render_many(archives, __MODULE__, "archive.json")}
  end

  def render("show.json", %{archive: nil}), do: %{archives: []}
  def render("show.json", %{archive: archive}) do
    %{archives: render_many([archive], __MODULE__, "archive.json")}
  end

  def render("archive.json", %{archive: archive}) do
    %{
      id: archive.exid,
      camera_id: archive.camera.exid,
      title: archive.title,
      from_date: Util.ecto_datetime_to_unix(archive.from_date),
      to_date: Util.ecto_datetime_to_unix(archive.to_date),
      created_at: Util.ecto_datetime_to_unix(archive.created_at),
      status: status(archive.status),
      requested_by: Util.deep_get(archive, [:user, :username], ""),
      requester_name: User.get_fullname(archive.user),
      requester_email: Util.deep_get(archive, [:user, :email], ""),
      embed_time: archive.embed_time,
      frames: archive.frames,
      public: archive.public
    }
  end

  defp status(0), do: "Pending"
  defp status(1), do: "Processing"
  defp status(2), do: "Completed"
  defp status(3), do: "Failed"
end
