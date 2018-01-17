defmodule EvercamMediaWeb.ArchiveView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{archives: archives, compares: compares}) do
    archives_list = render_many(archives, __MODULE__, "archive.json")
    compares_list =
      Enum.map(compares, fn(compare) -> render_compare_archive(compare) end)
    %{archives: archives_list ++ compares_list}
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
      public: archive.public,
      embed_code: "",
      type: "Clip",
      thumbnail: "data:image/jpeg;base64,#{Base.encode64(EvercamMedia.Snapshot.Storage.load_archive_thumbnail(archive.camera.exid, archive.exid))}"
    }
  end

  def render_compare_archive(compare) do
    %{
      id: compare.exid,
      camera_id: compare.camera.exid,
      title: compare.name,
      from_date: Util.ecto_datetime_to_unix(compare.before_date),
      to_date: Util.ecto_datetime_to_unix(compare.after_date),
      created_at: Util.ecto_datetime_to_unix(compare.inserted_at),
      status: compare_status(compare.status),
      requested_by: Util.deep_get(compare, [:user, :username], ""),
      requester_name: User.get_fullname(compare.user),
      requester_email: Util.deep_get(compare, [:user, :email], ""),
      embed_time: false,
      frames: 2,
      public: true,
      embed_code: compare.embed_code,
      type: "Compare",
      thumbnail: "data:image/jpeg;base64,#{Base.encode64(EvercamMedia.TimelapseRecording.S3.load_compare_thumbnail(compare.camera.exid, compare.exid))}"
    }
  end

  defp status(0), do: "Pending"
  defp status(1), do: "Processing"
  defp status(2), do: "Completed"
  defp status(3), do: "Failed"

  defp compare_status(0), do: "Processing"
  defp compare_status(1), do: "Completed"
  defp compare_status(2), do: "Failed"
end
