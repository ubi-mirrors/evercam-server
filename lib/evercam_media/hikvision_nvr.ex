defmodule EvercamMedia.HikvisionNVR do
  require Logger

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  def publish_stream_from_rtsp(exid, host, port, username, password, channel, starttime, endtime) do
    rtsp_url = "rtsp://#{username}:#{password}@#{host}:#{port}/Streaming/tracks/#{channel}/?starttime=#{starttime}&endtime=#{endtime}"
    kill_published_streams("rtmp://localhost:1935/live/#{exid}")
    "ffmpeg -rtsp_transport tcp -i '#{rtsp_url}' -f lavfi -i aevalsrc=0 -vcodec copy -acodec aac -map 0:0 -map 1:0 -shortest -strict experimental -f flv rtmp://localhost:1935/live/#{exid}"
    |> Porcelain.spawn_shell
    {:ok}
  end

  def get_stream_urls(_exid, host, port, username, password, starttime, endtime) do
    xml = "<?xml version='1.0' encoding='utf-8'?><CMSearchDescription><searchID>C5954E12-60B0-0001-954E-999096EF7420</searchID><trackList>"
    xml = "#{xml}<trackID>101</trackID></trackList><timeSpanList><timeSpan><startTime>#{starttime}</startTime><endTime>#{endtime}</endTime>"
    xml = "#{xml}</timeSpan></timeSpanList><maxResults>40</maxResults><searchResultPostion>0</searchResultPostion><metadataList>"
    xml = "#{xml}<metadataDescriptor>//metadata.psia.org/VideoMotion</metadataDescriptor></metadataList></CMSearchDescription>"

    url = "http://#{host}:#{port}/PSIA/ContentMgmt/search"
    case HTTPoison.post!(url, xml, ["Content-Type": "application/x-www-form-urlencoded", "Authorization": "Basic #{Base.encode64("#{username}:#{password}")}", "SOAPAction": "http://www.w3.org/2003/05/soap-envelope"]) do
      %HTTPoison.Response{body: body} ->
        url =
          body
          |> String.split("<playbackURI>")
          |> List.last
          |> String.split("</playbackURI>")
          |> List.first

        ip_index = url |> :binary.match("/Streaming") |> elem(0)
        refine_url = String.slice(url, ip_index..-1)
        pid = spawn(fn -> download_stream(host, port, username, password, refine_url) end)
        ConCache.put(:nvr_recording, "nvr_recording", pid)
        spawn(fn -> kill_streams() end)
        {:ok}
      _ ->
        Logger.error "[get_stream_urls] [#{url}] [#{xml}]"
        {:error}
    end
  end

  def download_stream(host, port, username, password, url) do
    xml = "<?xml version='1.0'?><downloadRequest version='1.0' xmlns='http://urn:selfextension:psiaext-ver10-xsd'>"
    xml = "#{xml}<playbackURI>rtsp://#{host}:#{port}#{url}"
    xml = "#{xml}</playbackURI></downloadRequest>"

    path = "#{@root_dir}/stream/stream.mp4"
    File.rm(path)
    url = "http://#{host}:#{port}/PSIA/Custom/SelfExt/ContentMgmt/download"
    opts = [stream_to: self()]
    HTTPoison.post(url, xml, ["Content-Type": "application/x-www-form-urlencoded", "Authorization": "Basic #{Base.encode64("#{username}:#{password}")}", "SOAPAction": "http://www.w3.org/2003/05/soap-envelope"], opts)
    |> collect_response(self(), <<>>)
  end

  def collect_response(id, par, data) do
    receive do
      %HTTPoison.AsyncStatus{code: 200, id: id} ->
        Logger.debug "Collect response status"
        collect_response(id, par, data)
      %HTTPoison.AsyncHeaders{headers: _headers, id: id} ->
        Logger.debug "Collect response headers"
        collect_response(id, par, data)
      %HTTPoison.AsyncChunk{chunk: chunk, id: id,} ->
        save_temporary(chunk)
        collect_response(id, par, data) # <> chunk
      %HTTPoison.AsyncEnd{id: _id} ->
        Logger.debug "Stream complete"
      _ ->
        Logger.debug "Unknown message in response"
        collect_response(id, par, data)
    after
      5000 ->
        Logger.debug "No response after 5 seconds."
    end
  end

  defp save_temporary(chunk) do
    "#{@root_dir}/stream/stream.mp4"
    |> File.open([:append, :binary, :raw], fn(file) -> IO.binwrite(file, chunk) end)
    |> case do
      {:error, :enoent} ->
        File.mkdir_p!("#{@root_dir}/stream/")
        save_temporary(chunk)
      _ -> :noop
    end
  end

  defp publish_stream() do
    Process.sleep(10000)
    path = "#{@root_dir}/stream/stream.mp4"
    "ffmpeg -re -i #{path} -vcodec copy -acodec copy -f flv rtmp://localhost:1935/live/stream"
    |> Porcelain.spawn_shell
  end

  defp kill_streams() do
    "#{@root_dir}/stream/stream.mp4"
    |> ffmpeg_pids
    |> Enum.each(fn(pid) -> Porcelain.shell("kill -9 #{pid}") end)
    publish_stream()
  end

  defp kill_published_streams(rtsp_url) do
    rtsp_url
    |> ffmpeg_pids
    |> Enum.each(fn(pid) -> Porcelain.shell("kill -9 #{pid}") end)
  end

  defp ffmpeg_pids(rtsp_url) do
    Porcelain.shell("ps -ef | grep ffmpeg | grep '#{rtsp_url}' | grep -v grep | awk '{print $2}'").out
    |> String.split
  end
end
