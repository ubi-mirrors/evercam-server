defmodule EvercamMedia.MoveClipsToS3 do
  require Logger

  @bucket "evercam-camera-assets"
  @seaweedfs Application.get_env(:evercam_media, :seaweedfs_url)
  @seaweedfs_1 Application.get_env(:evercam_media, :seaweedfs_url_1)

  def run do
    Archive.by_status(2)
    |> Enum.each(fn(archive) ->
      with :ok <- not_a_url(archive.url) do

        src_object = [
          "#{archive.camera.exid}/clips/#{archive.exid}",
          "#{archive.camera.exid}/clips/#{archive.exid}",
          "#{archive.camera.exid}/clips/thumb-#{archive.exid}"
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
            Logger.info "Getting Data from #{archive.camera.exid} : file type #{put_type(Enum.at(ext_object, x))}"
            save_archive_to_s3(data, Enum.at(dest_object, x), Enum.at(ext_object, x))
            Logger.info "Data Uploaded to S3 for #{archive.camera.exid} : file type #{put_type(Enum.at(ext_object, x))}"
          else
            :not_found -> :noop
          end
        end)
      else
        :not_ok -> :noop
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

  defp exist_on_seaweed?(src, ext) do
    case HTTPoison.get("#{@seaweedfs}/#{src}.#{ext}", ["Accept": "application/json"], hackney: [pool: :seaweedfs_download_pool, recv_timeout: 30_000_000]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: data}} -> {:ok, data}
      _error ->
        case HTTPoison.get("#{@seaweedfs_1}/#{src}.#{ext}", ["Accept": "application/json"], hackney: [pool: :seaweedfs_download_pool, recv_timeout: 30_000_000]) do
          {:ok, %HTTPoison.Response{status_code: 200, body: data}} -> {:ok, data}
          _error -> :not_found
        end
    end
  end

  defp not_a_url(nil), do: :ok
  defp not_a_url(_), do: :not_ok
end
