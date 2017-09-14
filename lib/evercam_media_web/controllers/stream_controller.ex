defmodule EvercamMediaWeb.StreamController do
  use EvercamMediaWeb, :controller

  @hls_dir "/tmp/hls"
  @hls_url Application.get_env(:evercam_media, :hls_url)

  def rtmp(conn, params) do
    ensure_nvr_stream(conn, params, params["nvr"])
  end

  def hls(conn, params) do
    code = ensure_nvr_hls(conn, params, params["nvr"])
    hls_response(code, conn, params)
  end

  defp hls_response(200, conn, params) do
    conn
    |> redirect(external: "#{@hls_url}/#{params["token"]}/index.m3u8")
  end

  defp hls_response(status, conn, _params) do
    conn
    |> put_status(status)
    |> text("")
  end

  def ts(conn, params) do
    conn
    |> redirect(external: "#{@hls_url}/#{params["token"]}/#{params["filename"]}")
  end

  defp ensure_nvr_hls(conn, params, is_nvr) when is_nvr in [nil, ""] do
    requester_ip = user_request_ip(conn)
    request_stream(params["camera_id"], params["token"], requester_ip, :check)
  end
  defp ensure_nvr_hls(_conn, _params, _is_nvr), do: 200

  defp ensure_nvr_stream(conn, params, is_nvr) when is_nvr in [nil, ""] do
    requester_ip = user_request_ip(conn)
    conn
    |> put_status(request_stream(params["camera_id"], params["name"], requester_ip, :kill))
    |> text("")
  end
  defp ensure_nvr_stream(conn, _params, _nvr) do
    conn |> put_status(200) |> text("")
  end

  defp request_stream(camera_exid, token, ip, command) do
    try do
      [username, password, rtsp_url] = Util.decode(token)
      camera = Camera.get(camera_exid)
      check_auth(camera, username, password)
      check_port(camera)
      stream(rtsp_url, token, camera.id, ip, command)
      200
    rescue
      error ->
        Util.error_handler(error)
        401
    end
  end

  defp check_port(camera) do
    host = Camera.host(camera)
    port = Camera.port(camera, "external", "rtsp")
    if !Util.port_open?(host, "#{port}") do
      raise "Invalid RTSP port to request the video stream"
    end
  end

  defp check_auth(camera, username, password) do
    if Camera.username(camera) != username || Camera.password(camera) != password do
      raise "Invalid credentials used to request the video stream"
    end
  end

  defp stream(rtsp_url, token, camera_id, ip, :check) do
    if length(ffmpeg_pids(rtsp_url)) == 0 do
      spawn(fn -> MetaData.delete_by_camera_id(camera_id) end)
      start_stream(rtsp_url, token, camera_id, ip, "hls")
    end
    sleep_until_hls_playlist_exists(token)
  end

  defp stream(rtsp_url, token, camera_id, ip, :kill) do
    kill_streams(rtsp_url, camera_id)
    start_stream(rtsp_url, token, camera_id, ip, "rtmp")
  end

  defp start_stream(rtsp_url, token, camera_id, ip, action) do
    rtsp_url
    |> construct_ffmpeg_command(token)
    |> Porcelain.spawn_shell
    spawn(fn -> insert_meta_data(rtsp_url, action, camera_id, ip, token) end)
  end

  defp kill_streams(rtsp_url, camera_id) do
    rtsp_url
    |> ffmpeg_pids
    |> Enum.each(fn(pid) -> Porcelain.shell("kill -9 #{pid}") end)
    spawn(fn -> MetaData.delete_by_camera_id(camera_id) end)
  end

  defp sleep_until_hls_playlist_exists(token, retry \\ 0)

  defp sleep_until_hls_playlist_exists(_token, retry) when retry > 30, do: :noop
  defp sleep_until_hls_playlist_exists(token, retry) do
    unless File.exists?("#{@hls_dir}/#{token}/index.m3u8") do
      :timer.sleep(500)
      sleep_until_hls_playlist_exists(token, retry + 1)
    end
  end

  defp ffmpeg_pids(rtsp_url) do
    Porcelain.shell("ps -ef | grep ffmpeg | grep '#{rtsp_url}' | grep -v grep | awk '{print $2}'").out
    |> String.split
  end

  defp construct_ffmpeg_command(rtsp_url, token) do
    "ffmpeg -rtsp_transport tcp -i '#{rtsp_url}' -f lavfi -i aevalsrc=0 -vcodec copy -acodec aac -map 0:0 -map 1:0 -shortest -strict experimental -f flv rtmp://localhost:1935/live/#{token}"
  end

  defp insert_meta_data(rtsp_url, action, camera_id, ip, token) do
    try do
      stream_in = get_stream_info(rtsp_url)

      rtsp_url
      |> ffmpeg_pids
      |> Enum.each(fn(pid) ->
        construct_params(camera_id, action, ip, pid, rtsp_url, token, stream_in)
        |> MetaData.insert_meta
      end)
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  defp get_stream_info(rtsp_url) do
    Porcelain.exec("ffprobe", ["-v", "error", "-show_streams", "#{rtsp_url}"], [err: :out]).out
    |> String.split("\n", trim: true)
    |> Enum.filter(fn(item) ->
      contain_attr?(item, "width") ||
      contain_attr?(item, "height") ||
      contain_attr?(item, "codec_name") ||
      contain_attr?(item, "pix_fmt") ||
      contain_attr?(item, "avg_frame_rate") ||
      contain_attr?(item, "bit_rate")
    end)
    |> Enum.map(fn(item) -> extract_params(item) end)
    |> List.flatten
  end

  defp construct_params(camera_id, action, ip, pid, rtsp_url, token, video_params) do
    extra =
      %{ip: ip, rtsp_url: rtsp_url, token: token}
      |> add_parameter("field", :width, video_params[:width])
      |> add_parameter("field", :height, video_params[:height])
      |> add_parameter("field", :codec, video_params[:codec_name])
      |> add_parameter("field", :pix_fmt, video_params[:pix_fmt])
      |> add_parameter("rate", :frame_rate, video_params[:avg_frame_rate])
      |> add_parameter("field", :bit_rate, video_params[:bit_rate])
    %{
      camera_id: camera_id,
      action: action,
      process_id: pid,
      extra: extra
    }
  end

  defp contain_attr?(item, attr) do
    case :binary.match(item, "#{attr}=") do
      :nomatch -> false
      {_index, _count} -> true
    end
  end

  defp extract_params(item) do
    case :binary.match(item, "=") do
      :nomatch -> ""
      {index, count} ->
        key = String.slice(item, 0, index)
        value = String.slice(item, (index + count), String.length(item))
        ["#{key}": value]
    end
  end

  defp add_parameter(params, _field, _key, nil), do: params
  defp add_parameter(params, _field, :width, "0"), do: params
  defp add_parameter(params, _field, :height, "0"), do: params
  defp add_parameter(params, "field", key, value) do
    Map.put(params, key, value)
  end
  defp add_parameter(params, "rate", key, value) do
    framerate = String.split(value, "/", trim: true) |> List.first
    Map.put(params, key, framerate)
  end
end
