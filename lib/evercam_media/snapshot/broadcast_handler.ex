defmodule EvercamMedia.Snapshot.BroadcastHandler do
  use GenStage
  alias EvercamMedia.Util

  @moduledoc """
  TODO
  """

  def init(:ok) do
    {:producer_consumer, :ok}
  end

  def handle_info({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    Util.broadcast_snapshot(camera_exid, image, timestamp)
    {:noreply, [], state}
  end

  def handle_info(_, state) do
    {:noreply, [], state}
  end
end
