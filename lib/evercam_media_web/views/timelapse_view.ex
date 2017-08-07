defmodule EvercamMediaWeb.TimelapseView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{timelapses: timelapses}) do
    %{timelapses: render_many(timelapses, __MODULE__, "timelapse.json")}
  end

  def render("show.json", %{timelapse: nil}), do: %{timelapse: []}
  def render("show.json", %{timelapse: timelapse}) do
    %{timelapses: render_many([timelapse], __MODULE__, "timelapse.json")}
  end

  def render("timelapse.json", %{timelapse: timelapse}) do
    %{
      id: timelapse.exid,
      camera_id: timelapse.camera.exid,
      camera_name: timelapse.camera.name,
      requested_by: timelapse.camera.owner.username,
      requester_name: User.get_fullname(timelapse.camera.owner),
      requester_email: timelapse.camera.owner.email,
      title: timelapse.title,
      frequency: timelapse.frequency,
      snapshot_count: timelapse.snapshot_count,
      resolution: timelapse.resolution,
      date_always: timelapse.date_always,
      time_always: timelapse.time_always,
      from_date: Util.ecto_datetime_to_unix(timelapse.from_datetime),
      to_date: Util.ecto_datetime_to_unix(timelapse.to_datetime),
      recreate_hls: timelapse.recreate_hls,
      status: status(timelapse.status),
      watermark_position: timelapse.watermark_position,
      watermark_logo: get_logo(timelapse.watermark_logo),
      last_snapshot_at: Util.ecto_datetime_to_unix(timelapse.last_snapshot_at),
      created_at: Util.ecto_datetime_to_unix(timelapse.inserted_at)
    }
  end

  defp status(0), do: "Active"
  defp status(1), do: "Scheduled"
  defp status(2), do: "Expired"
  defp status(3), do: "Paused"

  defp get_logo(image_binary) when image_binary in ["", nil], do: ""
  defp get_logo(image_binary) do
    "#{image_binary}"
  end
end
