defmodule EvercamMedia.Timelapse.PollHandler do
  @moduledoc """
  Provide functions to update timelapse worker config
  """
  alias EvercamMedia.Timelapse.Poller

  use GenStage

  def init(:ok) do
    {:producer_consumer, :ok}
  end

  def handle_info({:update_timelapse_config, worker_state}, state) do
    Poller.update_config(worker_state.poller, worker_state)
    {:noreply, [], state}
  end

  def handle_info(_, state) do
    {:noreply, [], state}
  end
end
