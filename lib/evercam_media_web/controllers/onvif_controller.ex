defmodule EvercamMediaWeb.ONVIFController do
  use EvercamMediaWeb, :controller
  alias EvercamMedia.ONVIFClient

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
