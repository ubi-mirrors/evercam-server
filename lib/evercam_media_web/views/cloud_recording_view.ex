defmodule EvercamMediaWeb.CloudRecordingView do
  use EvercamMedia.Web, :view

  def render("show.json", %{cloud_recording: cloud_recording}) do
    %{cloud_recordings: cloud_recording}
  end

  def render("cloud_recording.json", %{cloud_recording: cloud_recording}) do
    %{cloud_recordings: [base_cr_attributes(cloud_recording)]}
  end

  defp base_cr_attributes(cloud_recording) do
    %{
      frequency: cloud_recording.frequency,
      storage_duration: cloud_recording.storage_duration,
      status: cloud_recording.status,
      schedule: cloud_recording.schedule
    }
  end
end
