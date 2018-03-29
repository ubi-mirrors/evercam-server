defmodule EvercamMediaWeb.SDKController do
  use EvercamMediaWeb, :controller
  use PhoenixSwagger

  swagger_path :nvr_reboot do
    post "/sdk/nvr/reboot"
    summary "Reboot nvr."
    parameters do
      api_id :query, :string, "The Evercam API id for the requester.", required: true
      api_key :query, :string, "The Evercam API key for the requester", required: true
      ip :query, :string, "", required: true
      port :query, :string, "", required: true
      user :query, :string, "", required: true
      password :query, :string, "", required: true
    end
    response 201, "Success"
  end

  def nvr_reboot(conn, %{"ip" => ip, "port" => port, "user" => user, "password" => password}) do
    with %User{} <- conn.assigns[:current_user] do
      run_porcelain_shell(ip, port, user, password, conn)
    else
      nil ->
        render_error(conn, 401, "Unauthorized")
    end
  end

  defp run_porcelain_shell(ip, port, user, password, conn) do
    Porcelain.shell("nvr_reboot #{ip} #{port} #{user} #{password}")
    |> porcelain_output(conn)
  end

  defp porcelain_output(%Porcelain.Result{err: nil, out: output, status: 0}, conn) do
    case String.match?(output, ~r/success/) do
      true -> conn |> put_status(201) |> json(%{reboot: true})
      _ -> render_error(conn, 400, "Failed to reboot NVR.")
    end
  end
  defp porcelain_output(_, conn), do: render_error(conn, 400, "Failed to reboot NVR.")
end
