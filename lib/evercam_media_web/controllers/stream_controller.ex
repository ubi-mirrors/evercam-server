defmodule EvercamMediaWeb.StreamController do
  use EvercamMediaWeb, :controller
  import EvercamMedia.HikvisionNVR, only: [get_stream_info: 5]

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
    fullname = get_username(params["user"])
    request_stream(params["camera_id"], params["token"], requester_ip, fullname, :check)
  end
  defp ensure_nvr_hls(_conn, _params, _is_nvr), do: 200

  defp ensure_nvr_stream(conn, params, is_nvr) when is_nvr in [nil, ""] do
    requester_ip = get_requester_ip(conn, params["requester"])
    fullname = get_username(params["user"])
    conn
    |> put_status(request_stream(params["camera_id"], params["name"], requester_ip, fullname, :kill))
    |> text("")
  end
  defp ensure_nvr_stream(conn, _params, nvr) do
    Logger.info "[ensure_nvr_stream] [#{nvr}] [No stream request]"
    conn |> put_status(200) |> text("")
  end

  defp get_requester_ip(conn, requester) when requester in [nil, ""], do: user_request_ip(conn)
  defp get_requester_ip(_conn, requester), do: requester

  defp request_stream(camera_exid, token, ip, fullname, command) do
    try do
      [token_string, _name, exid] = Base.decode64!(token) |> String.split("|")
        # case Base.decode64!(token) |> String.split("|") do
        #   [str_toekn, _name] -> [str_toekn, camera_exid]
        #   [str_toekn, _name, c_exid] -> [str_toekn, c_exid]
        # end
      [username, password, rtsp_url] = Util.decode(token_string)
      camera = Camera.get_full(exid)
      check_auth(camera, username, password)
      check_port(camera)
      stream(rtsp_url, token, camera, ip, fullname, command)
      200
    rescue
      error ->
        Logger.error inspect(error)
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

  defp stream(rtsp_url, token, camera, ip, fullname, :check) do
    if length(ffmpeg_pids(rtsp_url)) == 0 do
      spawn(fn -> MetaData.delete_by_camera_and_action(camera.id, "hls") end)
      start_stream(rtsp_url, token, camera, ip, fullname, "hls")
    end
    sleep_until_hls_playlist_exists(token)
  end

  defp stream(rtsp_url, token, camera, ip, fullname, :kill) do
    kill_streams(rtsp_url, camera.id)
    start_stream(rtsp_url, token, camera, ip, fullname, "rtmp")
  end

  defp start_stream(rtsp_url, token, camera, ip, fullname, action) do
    rtsp_url
    |> construct_ffmpeg_command(token)
    |> Porcelain.spawn_shell
    spawn(fn -> insert_meta_data(rtsp_url, action, camera, ip, fullname, token) end)
  end

  defp kill_streams(rtsp_url, camera_id) do
    spawn(fn -> MetaData.delete_by_camera_and_action(camera_id, "rtmp") end)
    rtsp_url
    |> ffmpeg_pids
    |> Enum.each(fn(pid) -> Porcelain.shell("kill -9 #{pid}") end)
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
    "ffmpeg -rtsp_transport tcp -stimeout 6000000 -i '#{rtsp_url}' -f lavfi -i aevalsrc=0 -vcodec copy -acodec aac -map 0:0 -map 1:0 -shortest -strict experimental -f flv rtmp://localhost:1935/live/#{token}"
  end

  defp insert_meta_data(rtsp_url, action, camera, ip, fullname, token) do
    try do
      vendor = Camera.get_vendor_attr(camera, :exid)
      stream_in = get_stream_info(vendor, camera, rtsp_url)
      case has_params(stream_in) do
        false ->
          pid =
            rtsp_url
            |> ffmpeg_pids
            |> List.first

          construct_params(fullname, vendor, camera.id, action, ip, pid, rtsp_url, token, stream_in)
          |> MetaData.insert_meta
        _ -> Logger.debug "Stream not working for camera: #{camera.id}"
      end
    catch _type, error ->
      Logger.error inspect(error)
      Logger.error Exception.format_stacktrace System.stacktrace
    end
  end

  defp get_stream_info("hikvision", camera, rtsp_url) do
    ip = Camera.host(camera, "external")
    port = Camera.get_nvr_port(camera)
    cam_username = Camera.username(camera)
    cam_password = Camera.password(camera)
    channel = parse_channel(rtsp_url)
    stream_info = get_stream_info(ip, port, cam_username, cam_password, channel)
    [width, height] = get_resolution(stream_info.resolution)
    %{width: width, height: height, codec_name: stream_info.video_encoding, pix_fmt: "", avg_frame_rate: "#{stream_info.frame_rate}", bit_rate: stream_info.bitrate}
  end
  defp get_stream_info(_, _, rtsp_url) do
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

  defp construct_params(fullname, vendor, camera_id, action, ip, pid, rtsp_url, token, video_params) do
    framerate =
      case vendor do
        "hikvision" -> video_params[:avg_frame_rate]
        _ -> clean_framerate(video_params[:avg_frame_rate])
      end
    extra =
      %{requester: fullname, ip: ip, rtsp_url: rtsp_url, token: token}
      |> add_parameter("field", :width, video_params[:width])
      |> add_parameter("field", :height, video_params[:height])
      |> add_parameter("field", :codec, video_params[:codec_name])
      |> add_parameter("field", :pix_fmt, video_params[:pix_fmt])
      |> add_parameter("field", :frame_rate, framerate)
      |> add_parameter("field", :bit_rate, video_params[:bit_rate])
    %{
      camera_id: camera_id,
      action: action,
      process_id: pid,
      extra: extra
    }
  end

  defp has_params(video_params) do
    is_valid(video_params[:width]) && is_valid(video_params[:height]) && is_valid(video_params[:avg_frame_rate])
  end

  defp is_valid(value) when value in [nil, "", "0", "0/0"], do: true
  defp is_valid(_value), do: false

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

  defp clean_framerate(value) do
    value
    |> String.split("/", trim: true)
    |> List.first
    |> case do
      "" -> ""
      "0" -> "Full Frame Rate"
      "50" -> "1/2"
      "25" -> "1/4"
      "12" -> "1/8"
      "6" -> "1/16"
      frames when frames > 2600 ->
        Integer.floor_div(String.to_integer(frames), 1000)
      frames when frames > 50 ->
        Integer.floor_div(String.to_integer(frames), 100)
    end
  end

  defp get_resolution(resolution) do
    case String.split(resolution, "x") do
      [width, height] -> [width, height]
      _ -> ["", ""]
    end
  end

  def parse_channel(rtsp_url) do
    rtsp_url
    |> String.downcase
    |> String.split("/channels/")
    |> List.last
    |> String.split("/")
    |> List.first
    |> String.to_integer
  end

  defp get_username(value) when value in [nil, ""], do: ""
  defp get_username(value) do
    [user_fullname] = Util.decode(value)
    user_fullname
  end
end
