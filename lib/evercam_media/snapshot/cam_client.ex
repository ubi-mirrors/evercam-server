defmodule EvercamMedia.Snapshot.CamClient do
  @moduledoc """
  Client to talk with the camera for various data. Currently this only fetches snapshots.
  In future, we could expand this module to check camera status, video stream etc.
  """

  alias EvercamMedia.HTTPClient
  alias EvercamMedia.Util
  alias EvercamMedia.Snapshot.Error
  require Logger

  @doc """
  Connect to the camera and get the snapshot
  """
  def fetch_snapshot(args) do
    [username, password] = extract_auth_credentials(args)
    try do
      {time, response} =
        :timer.tc(fn ->
          case args[:vendor_exid] do
            "evercam-capture" -> HTTPClient.get(:basic_auth_android, args[:url], username, password)
            "samsung" -> HTTPClient.get(:digest_auth, args[:url], username, password)
            "hikvision" -> HTTPClient.get(:digest_auth, args[:url], username, password)
            "ubiquiti" -> HTTPClient.get(:cookie_auth, args[:url], username, password)
            _ -> HTTPClient.get(:basic_auth, args[:url], username, password)
          end
        end)
      spawn(fn -> save_response_time(args[:camera_exid], args[:timestamp], response, time/1_000_000) end)
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

  defp save_response_time(nil, _timestamp, _response, _time), do: :noop
  defp save_response_time(_camera_exid, nil, _response, _time), do: :noop
  defp save_response_time(camera_exid, timestamp, response, time) do
    date_time = Calendar.DateTime.Parse.unix!(timestamp)

    response_times =
      ConCache.dirty_get_or_store(:camera_response_times, camera_exid, fn() -> [date_time] end)
      |> reset_response_time_list(date_time)

    response_times =
      case parse_snapshot_response(response) do
        {:ok, _} ->
          List.insert_at(response_times, -1, Float.round(time, 4))
        {:error, error} ->
          error_no = error |> Error.parse |> error_code
          List.insert_at(response_times, -1, error_no)
      end
    ConCache.dirty_put(:camera_response_times, camera_exid, response_times)
  end

  defp reset_response_time_list(response_times, curr_date_time) do
    last_date_time = List.first(response_times)

    case Calendar.DateTime.diff(curr_date_time, last_date_time) do
      {:ok, seconds, _, :after} when seconds > 1800 ->
        response_times
        |> List.replace_at(0, Calendar.DateTime.advance!(last_date_time, 1))
        |> List.delete_at(1)
      _ -> response_times
    end
  end

  defp error_code(:system_limit), do: 0.5
  defp error_code(:emfile), do: 1
  defp error_code(:case_clause), do: 1.5
  defp error_code(:bad_request), do: 2
  defp error_code(:closed), do: 2.5
  defp error_code(:nxdomain), do: 3
  defp error_code(:ehostunreach), do: 3.5
  defp error_code(:enetunreach), do: 4
  defp error_code(:req_timedout), do: 4.5
  defp error_code(:timeout), do: 5
  defp error_code(:connect_timeout), do: 5.5
  defp error_code(:econnrefused), do: 6
  defp error_code(:not_found), do: 6.5
  defp error_code(:forbidden), do: 7
  defp error_code(:unauthorized), do: 7.5
  defp error_code(:device_error), do: 8
  defp error_code(:device_busy), do: 8.5
  defp error_code(:invalid_operation), do: 9
  defp error_code(:moved), do: 9.5
  defp error_code(:not_a_jpeg), do: 10
  defp error_code(_error), do: 0
end
