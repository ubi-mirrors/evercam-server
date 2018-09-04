defmodule EvercamMediaWeb.LogView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("show.json", %{total_pages: total_pages, camera_exid: camera_exid, camera_name: camera_name, logs: logs}) do
    %{
      logs: Enum.map(logs, fn(log) ->
        %{
          who: name(log.name),
          action: log.action,
          done_at: Util.ecto_datetime_to_unix(log.done_at),
          extra: log.extra
        }
      end),
      pages: total_pages,
      camera_name: camera_name,
      camera_exid: camera_exid
    }
  end

  def render("user_logs.json", %{user_logs: user_logs}) do
    %{
      user_logs: Enum.map(user_logs, fn(log) ->
        %{
          who: name(log.name),
          action: log.action,
          camera_exid: log.camera_exid,
          done_at: Util.ecto_datetime_to_unix(log.done_at),
          extra: log.extra
        }
      end)
    }
  end

  defp name(name) when name in [nil, ""], do: "Anonymous"
  defp name(name), do: name
end
