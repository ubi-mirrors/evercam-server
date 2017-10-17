defmodule EvercamMedia.TimelapseRecording.S3 do
  @moduledoc """
  TODO
  """
  require Logger
  alias EvercamMedia.TimelapseRecording.TimelapseRecordingSupervisor
  @region Application.get_env(:ex_aws, :region)

  def create_bucket(bucket_path) do
    Logger.debug "[create_bucket] [#{bucket_path}]"
    ExAws.S3.put_bucket("evercam-camera-assets/#{bucket_path}", @region)
    |> ExAws.request!
  end

  def save(camera_exid, timestamp, image, bucket_path) do
    Logger.debug "[#{camera_exid}] [snapshot_upload] [#{timestamp}]"
    camera = Camera.get_full(camera_exid)
    directory_path = construct_bucket_path(camera_exid, timestamp)
    file_path = construct_file_name(timestamp)

    case directory_path == bucket_path do
      true ->
        ExAws.S3.put_object("evercam-camera-assets", "#{directory_path}#{file_path}", image)
        |> ExAws.request!
      false ->
        create_bucket(directory_path)
        ExAws.S3.put_object("evercam-camera-assets", "#{directory_path}#{file_path}", image)
        |> ExAws.request!
        do_update_bucket_path(camera, directory_path)
    end
  end

  def days(camera_exid, year, month) do
    prefix = "#{camera_exid}/snapshots/#{year}/#{month}/"
    response = ExAws.S3.list_objects("evercam-camera-assets", prefix: prefix, delimiter: "/") |> ExAws.request!

    case response.body.common_prefixes do
      [] -> []
      days ->
        days
        |> Enum.map(fn(day) ->
          day.prefix
          |> String.replace(prefix, "")
          |> String.replace("/", "")
          |> String.to_integer
        end)
    end
  end

  def snapshots_info(camera_exid, year, month, day) do
    prefix = "#{camera_exid}/snapshots/#{year}/#{month}/#{day}/"
    response = ExAws.S3.list_objects("evercam-camera-assets", prefix: prefix, delimiter: "/") |> ExAws.request!

    case response.body.contents do
      [] -> []
      snapshots ->
        snapshots
        |> Enum.reject(fn(snapshot) -> snapshot.key == prefix end)
        |> Enum.map(fn(snapshot) ->
          key = snapshot.key
          created_at =
            key
            |> String.replace("#{camera_exid}/snapshots/", "")
            |> String.replace(".jpg", "")
            |> Timex.parse!("%Y/%m/%d/%H_%M_%S", :strftime)
            |> Timex.to_unix
            %{key: key, created_at: created_at}
        end)
    end
  end

  def load(camera_exid, timestamp) do
    file_path = convert_timestamp_to_path(timestamp)
    full_path = "#{camera_exid}/snapshots/#{file_path}"

    case ExAws.S3.get_object("evercam-camera-assets", full_path) |> ExAws.request do
      {:ok, response} -> {:ok, response.body}
      {:error, {:http_error, code, response}} ->
        message = EvercamMedia.XMLParser.parse_single(response.body, '/Error/Message')
        {:error, code, message}
    end
  end

  defp convert_timestamp_to_path(timestamp) do
    timestamp
    |> Calendar.DateTime.Parse.unix!
    |> Calendar.Strftime.strftime!("%Y/%m/%d/%H_%M_%S.jpg")
  end

  defp do_update_bucket_path(camera, bucket_path) do
    "timelapse_#{camera.exid}"
    |> String.to_atom
    |> Process.whereis
    |> TimelapseRecordingSupervisor.update_path_worker(camera, bucket_path)
  end

  def construct_bucket_path(camera_exid, timestamp) do
    timestamp
    |> Calendar.DateTime.Parse.unix!
    |> Calendar.Strftime.strftime!("#{camera_exid}/snapshots/%Y/%m/%d/")
  end

  def construct_file_name(timestamp) do
    timestamp
    |> Calendar.DateTime.Parse.unix!
    |> Calendar.Strftime.strftime!("%H_%M_%S.jpg")
  end
end
