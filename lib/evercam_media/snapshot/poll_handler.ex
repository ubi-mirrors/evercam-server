defmodule EvercamMedia.Snapshot.PollHandler do
  @moduledoc """
  TODO
  """
  alias EvercamMedia.Snapshot.Poller

  use GenStage

  def init(:ok) do
    {:producer_consumer, :ok}
  end

  def handle_info({:update_camera_config, worker_state}, state) do
    Poller.update_config(worker_state.poller, worker_state)
    {:noreply, [], state}
  end

  def handle_info(_, state) do
    {:noreply, [], state}
  end
end
