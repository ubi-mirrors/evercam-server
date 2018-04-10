defmodule EvercamMediaWeb.ONVIFController do
  use EvercamMediaWeb, :controller
  use PhoenixSwagger
  alias EvercamMedia.ONVIFClient

  swagger_path :invoke do
    get "/onvif/v20/{service}/{operation}"
    summary "Execute the operation of given service."
    parameters do
      service :path, :string, "", required: true
      operation :path, :string, "", required: true
      api_id :query, :string, "The Evercam API id for the requester."
      api_key :query, :string, "The Evercam API key for the requester."
    end
    tag "Onvif"
    response 200, "Success"
    response 401, "Invalid API keys"
  end

  def invoke(conn, %{"service" => service, "operation" => operation}) do
    ONVIFClient.request(conn.assigns.onvif_access_info, service, operation, conn.assigns.onvif_parameters) |> respond(conn)
  end

  defp respond({:ok, response}, conn) do
    conn
    |> json(response)
  end

  defp respond({:error, code, response}, conn) do
    conn
    |> put_status(code)
    |> json(response)
  end
end
