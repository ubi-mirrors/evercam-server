defmodule EvercamMedia.MoveClipsToS3 do
  require Logger

  @bucket "evercam-camera-assets"
  @seaweedfs Application.get_env(:evercam_media, :seaweedfs_url_1)
  @seaweedfs_1 Application.get_env(:evercam_media, :seaweedfs_url_1)

  def run do
    Archive.by_status(2)
    |> Enum.each(fn(archive) ->
      with :ok <- not_a_url(archive.url) do

        src_object = [
          "#{which_weed_it_is(archive.created_at)}/#{archive.camera.exid}/clips/#{archive.exid}",
          "#{which_weed_it_is(archive.created_at)}/#{archive.camera.exid}/clips/#{archive.exid}",
          "#{which_weed_it_is(archive.created_at)}/#{archive.camera.exid}/clips/thumb-#{archive.exid}"
        ]

        dest_object = [
          "#{archive.camera.exid}/clips/#{archive.exid}/#{archive.exid}",
          "#{archive.camera.exid}/clips/#{archive.exid}/#{archive.exid}",
          "#{archive.camera.exid}/clips/#{archive.exid}/thumb-#{archive.exid}"
        ]

        ext_object = [
          "mp4",
          "jpg",
          "jpg"
        ]

        Enum.each(0..2, fn(x) ->
          with {:ok, data} <- exist_on_seaweed?(Enum.at(src_object, x), Enum.at(ext_object, x)) do
            save_archive_to_s3(data, Enum.at(dest_object, x), Enum.at(ext_object, x))
          else
            :not_found ->
              Logger.info "No files on weed: #{archive.exid}"
          end
        end)
      else
        :not_ok ->
          Logger.info "Ignoring Archive: Type URL. #{archive.exid}"
      end
    end)
  end

  defp save_archive_to_s3(data, path, ext) do
    ExAws.S3.put_object(@bucket, "#{path}.#{ext}", data, [content_type: put_type(ext)])
    |> ExAws.request
    |> need_another_try(data, path, ext)
  end


  defp need_another_try({:ok, %{status_code: 200}}, _data, _path, _ext), do: :noop
  defp need_another_try(_, data, path, ext) do
    save_archive_to_s3(data, path, ext)
  end

  defp put_type("jpg"), do: "image/jpeg"
  defp put_type("mp4"), do: "video/mp4"

  defp which_weed_it_is(date) do
    actual_date =
      date
      |> Ecto.DateTime.to_erl
      |> Calendar.DateTime.from_erl!("Etc/UTC")

    crash_date =
      Calendar.DateTime.from_erl!({{2017,11,1},{00,00,00}}, "Etc/UTC")

    case Calendar.DateTime.diff(actual_date, crash_date) do
      {:ok, _, _, :before} -> @seaweedfs
      {:ok, _, _, :after} -> @seaweedfs_1
      {:ok, _, _, :same_time} -> @seaweedfs_1
    end
  end

  defp exist_on_seaweed?(src, ext) do
    case HTTPoison.get("#{src}.#{ext}", ["Accept": "application/json"], hackney: [pool: :seaweedfs_download_pool, recv_timeout: 30_000_000]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: data}} -> {:ok, data}
      _error -> :not_found
    end
  end

  defp not_a_url(nil), do: :ok
  defp not_a_url(_), do: :not_ok
end
