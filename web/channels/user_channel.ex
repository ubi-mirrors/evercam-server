defmodule EvercamMedia.UserChannel do
  use Phoenix.Channel
  alias EvercamMedia.Util

  def join("users:" <> username, _params, socket) do
    caller_username = Util.deep_get(socket, [:assigns, :current_user, :username], "")

    if username == caller_username do
      send(self(), {:after_join, username})
      {:ok, socket}
    else
      {:error, "Unauthorized."}
    end
  end

  def handle_info({:after_join, _username}, socket) do
    {:noreply, socket}
  end
end
