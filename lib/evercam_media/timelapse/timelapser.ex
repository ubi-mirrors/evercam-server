defmodule EvercamMedia.Timelapse.Timelapser do
  @moduledoc """
  Provides functions to create timelapse
  """

  use GenStage
  alias EvercamMedia.Snapshot.CamClient
  alias EvercamMedia.Snapshot.Storage
  require Logger

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  ################
  ## Client API ##
  ################

  @doc """
  Start the timelapse server for a given timelapse.
  """
  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: args[:name])
  end

  @doc """
  Get the state of the timelapse worker.
  """
  def get_state(timelapse_server) do
    GenStage.call(timelapse_server, :get_state)
  end

  @doc """
  Get the configuration of the timelapse worker.
  """
  def get_config(timelapse_server) do
    GenStage.call(timelapse_server, :get_timelapse_config)
  end

  @doc """
  Update the configuration of the timelapse worker
  """
  def update_config(timelapse_server, config) do
    GenStage.cast(timelapse_server, {:update_timelapse_config, config})
  end

  @doc """
  Get a snapshot from the camera and create new of HLS if have 24 frames
  """
  def get_snapshot(timelapse_server, {:poll, timestamp}) do
    GenStage.cast(timelapse_server, {:get_camera_snapshot, timestamp})
  end

  ######################
  ## Server Callbacks ##
  ######################

  @doc """
  Initialize the timelapse server
  """
  def init(args) do
    {:ok, snapshot_manager} = GenStage.start_link(EvercamMedia.Timelapse.StorageHandler, :ok)
    {:ok, poll_manager} = GenStage.start_link(EvercamMedia.Timelapse.PollHandler, :ok)
    {:ok, poller} = EvercamMedia.Timelapse.Poller.start_link(args)
    args = Map.merge args, %{
      poller: poller,
      snapshot_manager: snapshot_manager,
      poll_manager: poll_manager
    }
    {:producer, args}
  end

  @doc """
  Server callback for restarting timelapse poller
  """
  def handle_call(:restart_timelapse_poller, _from, state) do
    {:reply, nil, [], state}
  end

  @doc """
  Server callback for stopping timelapse poller
  """
  def handle_call(:stop_timelapse_poller, _from, state) do
    {:reply, nil, [], state}
  end

  @doc """
  Server callback for getting timelapse config
  """
  def handle_call(:get_timelapse_config, _from, state) do
    {:reply, get_config_from_state(:config, state), [], state}
  end

  @doc """
  Server callback for getting worker state
  """
  def handle_call(:get_state, _from, state) do
    {:reply, state, [], state}
  end

  @doc """
  Get a snapshot from the camera and create new of HLS if have 24 frames
  """
  def handle_cast({:get_camera_snapshot, timestamp}, state) do
    _get_snapshots_create_hls_chunk(state, timestamp)
    {:noreply, [], state}
  end

  @doc """
  Server callback for updating timelapse config
  """
  def handle_cast({:update_timelapse_config, config}, state) do
    updated_config = Map.merge state, config
    GenStage.sync_info(state.poll_manager, {:update_timelapse_config, updated_config})
    {:noreply, [], updated_config}
  end

  @doc """
  Server callback for camera_reply
  """
  def handle_info({:camera_reply, camera_exid, image, timestamp}, state) do
    data = {camera_exid, timestamp, image}
    GenStage.sync_info(state.snapshot_manager, {:got_snapshot, data})
    {:noreply, [], state}
  end

  @doc """
  Take care of unknown messages which otherwise would trigger function clause mismatch error.
  """
  def handle_info(_msg, state) do
    {:noreply, [], state}
  end

  #####################
  # Private functions #
  #####################

  defp get_config_from_state(:config, state) do
    Map.get(state, :config)
  end

  defp _get_snapshots_create_hls_chunk(state, timestamp) do
    config = get_config_from_state(:config, state)
    worker = self()
    get_snapshots(state, config, timestamp, worker)
  end

  defp get_snapshots(state, config, timestamp, worker) do
    spawn fn ->
      case try_snapshot(config, 1) do
        {:ok, image} ->
          send worker, {:camera_reply, config.camera_exid, image, timestamp}
          images_index = get_file_index(config.camera_exid, state.name)
          source_path = "#{@root_dir}/#{state.config.camera_exid}/timelapses/#{state.name}/images/#{images_index}.jpg"
          File.write(source_path, image)
          metadata = Storage.load_timelapse_metadata(state.config.camera_exid, state.name)
          cond do
            metadata == %{} && images_index > 25 -> create_hls(state)
            metadata == %{} && images_index == 24 -> create_hls(state)
            metadata == %{} && images_index > 0 && images_index < 25 ->
              false
            metadata && images_index >= 24 ->
              create_new_video_chunk(state, metadata)
            true ->
              true
          end
          spawn(fn -> update_timelapse(state, timestamp) end)
        {:error, _error} ->
          false
      end
    end
  end

  defp try_snapshot(config, 3) do
    case CamClient.fetch_snapshot(config) do
      {:ok, image} -> {:ok, image}
      {:error, error} -> {:error, error}
    end
  end

  defp try_snapshot(config, attempt) do
    case CamClient.fetch_snapshot(config) do
      {:ok, image} -> {:ok, image}
      {:error, _error} -> try_snapshot(config, attempt + 1)
    end
  end

  # defp check_images_and_create_hls(images, state) do
  #   source_path = "#{@root_dir}/#{state.config.camera_exid}/timelapses/#{state.name}/images/#{images - 1}.jpg"
  #   loop_list(source_path)
  # end

  defp create_hls(state) do
    timelapse_path = "#{@root_dir}/#{state.config.camera_exid}/timelapses/#{state.name}/"
    Porcelain.shell("bash #{timelapse_path}build.sh", [err: :out]).out

    new_index = get_ts_fileindex(timelapse_path)
    Storage.save_timelapse_metadata(state.config.camera_exid, state.name, new_index.low, new_index.medium, new_index.high)
    clean_images(state, "images")
    upload_to_seaweed(state, timelapse_path)
    state
  end

  def loop_list(_source_path, _index) do
    # File.copy()
    # download_snapshot(snap, camera_exid, path, index)
    # loop_list(path, index + 1)
  end
  def loop_list([], _camera_exid, _path, _index), do: :noop

  defp create_new_video_chunk(state, new_index) do
    timelapse_path = "#{@root_dir}/#{state.config.camera_exid}/timelapses/#{state.name}/"
    create_bashfile(timelapse_path, new_index)
    Porcelain.shell("bash #{timelapse_path}build.sh", [err: :out]).out

    update_menifiest(state.config.camera_exid, state.name, "low", new_index["low"]);
    update_menifiest(state.config.camera_exid, state.name, "medium", new_index["medium"]);
    update_menifiest(state.config.camera_exid, state.name, "high", new_index["high"]);
    Storage.save_timelapse_metadata(state.config.camera_exid, state.name, new_index["low"] + 1, new_index["medium"] + 1, new_index["high"] + 1)
    upload_to_seaweed(state, timelapse_path)
    clean_images(state, "images")
  end

  defp upload_to_seaweed(state, timelapse_path) do
    spawn(fn ->
      "#{timelapse_path}ts/"
      |> File.ls!
      |> Enum.each(fn(file) ->
        Storage.save_hls_files(state.config.camera_exid, state.name, file)
      end)
      clean_images(state, "ts")
    end)
  end

  defp get_ts_fileindex(timelapse_path) do
    hls_path = "#{timelapse_path}ts/"
    files = File.ls!(hls_path)
    low = files |> Enum.filter(fn(f) -> String.match?(f, ~r/low/) and !String.match?(f, ~r/low.m3u8/) end) |> Enum.count
    medium = files |> Enum.filter(fn(f) -> String.match?(f, ~r/medium/) and !String.match?(f, ~r/medium.m3u8/) end) |> Enum.count
    high = files |> Enum.filter(fn(f) -> String.match?(f, ~r/high/) and !String.match?(f, ~r/high.m3u8/) end) |> Enum.count

    %{low: low, medium: medium, high: high}
  end

  defp update_menifiest(camera_exid, timelapse_id, file_name, file_index) do
    content = Storage.load_hls_menifiest(camera_exid, timelapse_id, "#{file_name}.m3u8") |> String.replace("\n#EXT-X-ENDLIST", "")
    content = content <> "#EXT-X-DISCONTINUITY"
    content = content <> "\n#EXTINF:1.100000,"
    content = content <> "\n#{file_name}#{file_index}.ts"
    content = content <> "\n#EXT-X-ENDLIST\n"
    Storage.seaweedfs_save_hls_file(camera_exid, timelapse_id, content, "#{file_name}.m3u8")
  end

  defp create_bashfile(timelapse_path, file_index) do
    File.rm("#{timelapse_path}build.sh")
    images_path = "#{timelapse_path}images/"
    ts_path = "#{timelapse_path}ts/"

    bash_content = "#!/bin/bash"
    bash_content = bash_content <> "\nffmpeg -threads 1 -y -framerate 24 -i #{images_path}/%d.jpg -c:v libx264 -pix_fmt yuv420p -preset slow -tune stillimage -b:v 64K -maxrate 10000k -bufsize 64k -crf 28 -r 24 #{ts_path}/low#{file_index["low"]}.ts"
    bash_content = bash_content <> "\nffmpeg -threads 1 -y -framerate 24 -i #{images_path}/%d.jpg -c:v libx264 -pix_fmt yuv420p -preset slow -tune stillimage -b:v 64K -maxrate 13000k -bufsize 64k -crf 28 -r 24 #{ts_path}/medium#{file_index["medium"]}.ts"
    bash_content = bash_content <> "\nffmpeg -threads 1 -y -framerate 24 -i #{images_path}/%d.jpg -c:v libx264 -pix_fmt yuv420p -preset slow -tune stillimage -b:v 64K -maxrate 16000k -bufsize 64k -crf 28 -r 24 #{ts_path}/high#{file_index["high"]}.ts"
    File.write("#{timelapse_path}build.sh", bash_content)
  end

  defp get_file_index(camera_id, timelapse_id) do
    images_path = "#{@root_dir}/#{camera_id}/timelapses/#{timelapse_id}/images/"
    case File.exists?(images_path) do
      true ->
        Enum.count(File.ls!(images_path))
      _ ->
        0
    end
  end

  defp update_timelapse(state, timestamp) do
    timelapse = Timelapse.by_exid("#{state.name}")
    snap_date =
      timestamp
      |> Calendar.DateTime.Parse.unix!
      |> Calendar.DateTime.to_erl
      |> Calendar.DateTime.from_erl!("Etc/UTC")
    params = %{last_snapshot_at: snap_date, snapshot_count: timelapse.snapshot_count + 1}
    Timelapse.update_timelapse(timelapse, params)
  end

  defp clean_images(state, directory) do
    images_path = "#{@root_dir}/#{state.config.camera_exid}/timelapses/#{state.name}/#{directory}/"
    File.rm_rf!(images_path)
    File.mkdir_p(images_path)
    state
  end
end
