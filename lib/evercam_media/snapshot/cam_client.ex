defmodule EvercamMedia.Snapshot.CamClient do
  @moduledoc """
  Client to talk with the camera for various data. Currently this only fetches snapshots.
  In future, we could expand this module to check camera status, video stream etc.
  """

  alias EvercamMedia.HTTPClient
  alias EvercamMedia.Util
  require Logger

  @doc """
  Connect to the camera and get the snapshot
  """
  def fetch_snapshot(args) do
    [username, password] = extract_auth_credentials(args)
    try do
      response =
        case args[:vendor_exid] do
          "evercam-capture" -> HTTPClient.get(:basic_auth_android, args[:url], username, password)
          "samsung" -> HTTPClient.get(:digest_auth, args[:url], username, password)
          "ubiquiti" -> HTTPClient.get(:cookie_auth, args[:url], username, password)
          _ -> HTTPClient.get(:basic_auth, args[:url], username, password)
        end
      parse_snapshot_response(response)
    catch _type, error ->
      {:error, error}
    end
  end


  ## Private functions

  defp parse_snapshot_response({:ok, response}) do
    case Util.jpeg?(response.body) do
      true -> {:ok, response.body}
      _ -> {:error, %{reason: parse_reason(response.body), response: parse_response(response.body)}}
    end
  end

  defp parse_snapshot_response(response) do
    response
  end

  defp parse_reason(response_text) do
    cond do
      String.contains?(response_text, "Not Found") ->
        :not_found
      String.contains?(response_text, "Forbidden") ->
        :forbidden
      String.contains?(response_text, "Unauthorized") ->
        :unauthorized
      String.contains?(response_text, "Unsupported Authorization Type") ->
        :unauthorized
      String.contains?(response_text, "Device Busy") ->
        :device_busy
      String.contains?(response_text, "Device Error") ->
        :device_error
      String.contains?(response_text, "Invalid Operation") ->
        :invalid_operation
      String.contains?(response_text, "Moved Permanently") ->
        :moved
      String.contains?(response_text, "The document has moved") ->
        :moved
      true ->
        :not_a_jpeg
    end
  end

  defp parse_response(response_text) do
    case String.valid?(response_text) do
      true -> response_text
      false -> Base.encode64(response_text)
    end
  end

  defp extract_auth_credentials(%{vendor_exid: _vendor_exid, url: _url, username: username, password: password}) do
    [username, password]
  end

  defp extract_auth_credentials(%{vendor_exid: _vendor_exid, url: _url, auth: auth}) do
    String.split(auth, ":")
  end

  defp extract_auth_credentials(args) do
    String.split(args[:auth], ":")
  end
end
