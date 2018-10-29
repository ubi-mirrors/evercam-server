defmodule EvercamMediaWeb.CompareView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{compares: compares}) do
    %{compares: render_many(compares, __MODULE__, "compare.json")}
  end

  def render("show.json", %{compare: nil}), do: %{compares: []}
  def render("show.json", %{compare: compare}) do
    %{compares: render_many([compare], __MODULE__, "compare.json")}
  end

  def render("compare.json", %{compare: compare}) do
    %{
      id: compare.exid,
      camera_id: compare.camera.exid,
      title: compare.name,
      from_date: Util.ecto_datetime_to_unix(compare.before_date),
      to_date: Util.ecto_datetime_to_unix(compare.after_date),
      created_at: Util.ecto_datetime_to_unix(compare.inserted_at),
      status: status(compare.status),
      requested_by: Util.deep_get(compare, [:user, :username], ""),
      requester_name: User.get_fullname(compare.user),
      requester_email: Util.deep_get(compare, [:user, :email], ""),
      embed_code: compare.embed_code,
      embed_time: false,
      frames: 2,
      public: compare.public,
      file_name: "",
      media_url: "",
      type: "compare",
      thumbnail_url: "#{EvercamMediaWeb.Endpoint.static_url}/v1/cameras/#{compare.camera.exid}/archives/#{compare.exid}/thumbnail?type=compare"
    }
  end

  defp status(0), do: "Processing"
  defp status(1), do: "Completed"
  defp status(2), do: "Failed"
end
