defmodule EvercamMedia.TimelapseRecording.StorageHandler do
  @moduledoc """
  TODO
  """

  require Logger
  alias EvercamMedia.TimelapseRecording.S3
  use GenStage

  def init(:ok) do
    {:producer_consumer, :ok}
  end

  def handle_info({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image, bucket_path} = data
    Logger.debug "S3 storage called"
    spawn fn -> S3.save(camera_exid, timestamp, image, bucket_path) end
    {:noreply, [], state}
  end

  def handle_info(_, state) do
    {:noreply, [], state}
  end
end
