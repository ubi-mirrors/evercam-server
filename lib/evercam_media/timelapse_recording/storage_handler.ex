defmodule EvercamMedia.TimelapseRecording.StorageHandler do
  @moduledoc """
  TODO
  """

  require Logger
  alias EvercamMedia.TimelapseRecording.S3
  use GenEvent

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image, bucket_path} = data
    Logger.debug "S3 storage called"
    spawn fn -> S3.save(camera_exid, timestamp, image, bucket_path) end
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
