defmodule EvercamMedia.Snapmail.StorageHandler do
  @moduledoc """
  Provides functions to save snapshot captured for snapshot
  """

  use GenStage
  alias EvercamMedia.Snapshot.Storage

  def init(:ok) do
    {:producer_consumer, :ok}
  end

  def handle_info({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    spawn fn -> Storage.save(camera_exid, timestamp, image, "Evercam SnapMail") end
    {:noreply, [], state}
  end

  def handle_info(_, state) do
    {:noreply, [], state}
  end
end
