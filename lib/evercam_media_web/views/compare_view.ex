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
      name: compare.name,
      requested_by: Util.deep_get(compare, [:camera, :owner, :username], ""),
      requester_name: User.get_fullname(compare.camera.owner),
      requester_email: Util.deep_get(compare, [:camera, :owner, :email], ""),
      before: Util.ecto_datetime_to_unix(compare.before_date),
      after: Util.ecto_datetime_to_unix(compare.after_date),
      embed_code: compare.embed_code,
      gif_url: "#{EvercamMediaWeb.Endpoint.static_url}/v1/cameras/#{compare.camera.exid}/compare/#{compare.exid}.gif",
      mp4_url: "#{EvercamMediaWeb.Endpoint.static_url}/v1/cameras/#{compare.camera.exid}/compare/#{compare.exid}.mp4",
      Status: status(compare.status),
      created_at: Util.ecto_datetime_to_unix(compare.inserted_at)
    }
  end

  defp status(0), do: "Processing"
  defp status(1), do: "Done"
  defp status(2), do: "Failed"
end
