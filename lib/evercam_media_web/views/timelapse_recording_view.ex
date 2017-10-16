defmodule EvercamMediaWeb.TimelapsedRecordingView do
  use EvercamMediaWeb, :view

  def render("show.json", %{timelapse_recording: timelapse_recording}) do
    %{timelapse_recordings: timelapse_recording}
  end

  def render("timelapse_recording.json", %{timelapse_recording: timelapse_recording}) do
    %{timelapse_recordings: [base_cr_attributes(timelapse_recording)]}
  end

  defp base_cr_attributes(timelapse_recording) do
    %{
      frequency: timelapse_recording.frequency,
      storage_duration: timelapse_recording.storage_duration,
      status: timelapse_recording.status,
      schedule: timelapse_recording.schedule
    }
  end
end
