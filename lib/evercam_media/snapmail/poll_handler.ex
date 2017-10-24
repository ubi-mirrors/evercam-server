defmodule EvercamMedia.Snapmail.PollHandler do
  @moduledoc """
  Provide functions to update snapmail worker config
  """
  alias EvercamMedia.Snapmail.Poller
  use GenStage

  def init(:ok) do
    {:producer_consumer, :ok}
  end

  def handle_info({:update_snapmail_config, worker_state}, state) do
    Poller.update_config(worker_state.poller, worker_state)
    {:noreply, [], state}
  end

  def handle_info(_, state) do
    {:noreply, [], state}
  end
end
