defmodule EvercamMediaWeb.SnapshotExtractorView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{snapshot_extractor: snapshot_extractors}) do
    %{SnapshotExtractor: render_many(snapshot_extractors, __MODULE__, "snapshot_extractor.json")}
  end

  def render("show.json", %{snapshot_extractor: snapshot_extractor}) do
    %{SnapshotExtractor: render_many([snapshot_extractor], __MODULE__, "snapshot_extractor.json")}
  end

  def render("snapshot_extractor.json", %{snapshot_extractor: snapshot_extractor}) do
    %{
      id: snapshot_extractor.id,
      camera: snapshot_extractor.camera.name,
      from_date: Util.ecto_datetime_to_unix(snapshot_extractor.from_date),
      to_date: Util.ecto_datetime_to_unix(snapshot_extractor.to_date),
      interval: snapshot_extractor.interval,
      schedule: snapshot_extractor.schedule,
      status: snapshot_extractor.status,
      requestor: snapshot_extractor.requestor,
      created_at: Util.ecto_datetime_to_unix(snapshot_extractor.created_at),
      updated_at: Util.ecto_datetime_to_unix(snapshot_extractor.updated_at)
    }
  end
end
