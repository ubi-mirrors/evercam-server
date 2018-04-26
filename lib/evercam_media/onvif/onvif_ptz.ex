defmodule EvercamMedia.ONVIFPTZ do
  alias EvercamMedia.ONVIFClient

  def get_nodes(access_info) do
    access_info |> ptz_request("GetNodes")
  end

  def get_configurations(access_info) do
    access_info |> ptz_request("GetConfigurations")
  end

  def get_presets(access_info, profile_token) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken>"
    with {:ok, response} <- access_info |> ptz_request("GetPresets", parameters),
          presets = response |> parse_ptz_response |> Map.get("Preset") |> Enum.filter(&(Map.get(&1, "Name") != nil)),
    do: {:ok, Map.put(%{}, "Presets", presets)}
  end

  defp parse_ptz_response(:ok), do: %{"Preset" => []}
  defp parse_ptz_response(response), do: response

  def get_status(access_info, profile_token) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken>"
    access_info |> ptz_request("GetStatus", parameters)
  end

  def goto_preset(access_info, profile_token, preset_token, speed \\ []) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken><PresetToken>#{preset_token}</PresetToken>" <>
      case pan_tilt_zoom_vector speed do
        "" -> ""
        vector -> "<Speed>#{vector}</Speed>"
      end
    access_info |> ptz_request("GotoPreset", parameters)
  end

  def relative_move(access_info, profile_token, translation, speed \\ []) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken><Translation>#{pan_tilt_zoom_vector translation}</Translation>" <>
      case pan_tilt_zoom_vector speed do
        "" -> ""
        vector -> "<Speed>#{vector}</Speed>"
      end
    access_info |> ptz_request("RelativeMove", parameters)
  end

  def continuous_move(access_info, profile_token, velocity \\ []) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken>" <>
      case pan_tilt_zoom_vector velocity do
        "" -> ""
        vector -> "<Velocity>#{vector}</Velocity>"
      end
    access_info |> ptz_request("ContinuousMove", parameters)
  end

  def goto_home_position(access_info, profile_token, speed \\ []) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken>" <>
      case pan_tilt_zoom_vector speed do
        "" -> ""
        vector  -> "<Speed>#{vector}</Speed>"
      end
    access_info |> ptz_request("GotoHomePosition", parameters)
  end

  def remove_preset(access_info, profile_token, preset_token) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken><PresetToken>#{preset_token}</PresetToken>"
    access_info
    |> ptz_request("RemovePreset", parameters)
  end

  def set_preset(access_info, profile_token, preset_name \\ "", preset_token \\ "") do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken>" <>
      case preset_name do
        "" -> ""
        _ -> "<PresetName>#{preset_name}</PresetName>"
      end <>
      case preset_token do
        "" -> ""
        _ -> "<PresetToken>#{preset_token}</PresetToken>"
      end
    access_info |> ptz_request("SetPreset", parameters)
  end

  def set_home_position(access_info, profile_token) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken>"
    access_info |> ptz_request("SetHomePosition", parameters)
  end

  def stop(access_info, profile_token) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken>"
    access_info |> ptz_request("Stop", parameters)
  end

  def pan_tilt_zoom_vector(vector) do
    pan_tilt =
      case {vector[:x], vector[:y]}  do
        {nil, _} -> ""
        {_, nil} -> ""
        {x, y}  -> "<PanTilt x=\"#{x}\" y=\"#{y}\" xmlns=\"http://www.onvif.org/ver10/schema\"/>"
      end
    zoom =
      case vector[:zoom] do
        nil -> ""
        zoom  -> "<Zoom x=\"#{zoom}\"  xmlns=\"http://www.onvif.org/ver10/schema\"/>"
      end
    pan_tilt <> zoom
  end

  defp ptz_request(access_info, operation, parameters \\ "") do
    ONVIFClient.request(access_info, "PTZ", operation, parameters)
  end
end
