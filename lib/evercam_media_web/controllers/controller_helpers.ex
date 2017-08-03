defmodule EvercamMediaWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  alias EvercamMediaWeb.ErrorView

  def render_error(conn, status, message) do
    conn
    |> put_status(status)
    |> render(ErrorView, "error.json", %{message: message})
  end

  def user_request_ip(conn) do
    x_real_ip = Plug.Conn.get_req_header(conn, "x-real-ip")
    x_real_ip |> List.first |> get_ip(conn)
  end

  def get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [] -> ""
      [user_agent|_rest] -> parse_user_agent(user_agent)
    end
  end

  defp get_ip(nil, conn), do: conn.remote_ip |> Tuple.to_list |> Enum.join(".")
  defp get_ip(user_ip, _conn), do: user_ip

  defp parse_user_agent(nil), do: ""
  defp parse_user_agent(user_agent), do: user_agent
end
