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
      created_at: Util.ecto_datetime_to_unix(compare.inserted_at),
      embed_code: compare.embed_code,
    }
  end
end
