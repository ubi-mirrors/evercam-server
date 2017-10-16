defmodule EvercamMedia.TimelapseRecording.PollHandler do
  @moduledoc """
  TODO
  """
  alias EvercamMedia.TimelapseRecording.Poller

  use GenEvent

  def handle_event({:update_camera_config, worker_state}, state) do
    Poller.update_config(worker_state.poller, worker_state)
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
