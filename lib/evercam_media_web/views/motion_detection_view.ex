defmodule EvercamMediaWeb.MotionDetectionView do
  use EvercamMedia.Web, :view

  def render("show.json", %{motion_detection: nil}), do: %{motion_detections: []}
  def render("show.json", %{motion_detection: motion_detection}) do
    %{motion_detections: render_many([motion_detection], __MODULE__, "motion_detection.json")}
  end

  def render("motion_detection.json", %{motion_detection: motion_detection}) do
    %{
      frequency: motion_detection.frequency,
      minPosition: motion_detection.minPosition,
      step: motion_detection.step,
      min: motion_detection.min,
      threshold: motion_detection.threshold,
      enabled: motion_detection.enabled,
      alert_interval_min: motion_detection.alert_interval_min,
      sensitivity: motion_detection.sensitivity,
      x1: motion_detection.x1,
      y1: motion_detection.y1,
      x2: motion_detection.x2,
      y2: motion_detection.y2,
      alert_email: motion_detection.alert_email,
      schedule: motion_detection.schedule,
      emails: motion_detection.emails
    }
  end
end
