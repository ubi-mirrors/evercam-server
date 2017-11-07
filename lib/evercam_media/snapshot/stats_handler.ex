defmodule EvercamMedia.Snapshot.StatsHandler do
  @moduledoc """
  TODO
  """

  use GenStage

  @doc """
  Currently this module is just a placeholder.
  We could use this to populate stats such as
  * What is the request/response time for the last snapshot
  * What is the status of a camera
  * What is the history of response of a camera

  With these data stored, it would be possible to alter the camera worker
  based on the stats. For eg., if the camera consistently reponds with a delay of
  more than 1s, we modify the worker to NOT poll it for every second to get a snapshot even
  if the configuration of the camera says so.
  """

  def init(:ok) do
    {:producer_consumer, :ok}
  end

  def handle_info({:snapshot_error, data}, state) do
    store_error(:snapshot_error, data)
    {:noreply, [], state}
  end

  def handle_info(_, state) do
    {:noreply, [], state}
  end

  defp store_error(:snapshot_error, {camera_exid, timestamp, error}) do
    ConCache.update(:snapshot_error, camera_exid, fn(old_value) ->
      old_value = Enum.slice List.wrap(old_value), 0, 99
      new_value = [
        timestamp: timestamp,
        type: Map.get(error, :__struct__),
        error: error
      ]
      [new_value | old_value]
    end)
  end
end
