defmodule PTZTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  import EvercamMediaWeb.ConnCase ,only: [parse_onvif_error_type: 1]
  alias EvercamMedia.ONVIFPTZ

  @auth Application.get_env(:evercam_media, :dummy_auth)

  @access_info %{"url" => "http://recorded_response", "auth" => @auth}

  test "get_nodes method on hikvision camera" do
    use_cassette "get_nodes" do
      {:ok, response} = ONVIFPTZ.get_nodes @access_info
      assert response |> Map.get("PTZNode") |> Map.get("Name") == "PTZNODE"
      assert response |> Map.get("PTZNode") |> Map.get("token") == "PTZNODETOKEN"
    end
  end

  test "get_configurations method on hikvision camera" do
    use_cassette "get_configurations" do
      {:ok, response} = ONVIFPTZ.get_configurations @access_info
      assert response |> Map.get("PTZConfiguration") |> Map.get("Name") == "PTZ"
      assert response |> Map.get("PTZConfiguration") |> Map.get("NodeToken") == "PTZNODETOKEN"
    end
  end

  test "get_presets method on hikvision camera" do
    use_cassette "get_presets" do
      {:ok, response} = ONVIFPTZ.get_presets(@access_info, "Profile_1")
      [first_preset | _] = response |> Map.get("Presets")
      assert first_preset |> Map.get("Name") == "Back Main Yard"
      assert first_preset |> Map.get("token") == "1"
    end
  end

  @tag :capture_log
  test "get_presets method returns error" do
    use_cassette "get_presets_with_error" do
      {:error, code, response} = ONVIFPTZ.get_presets(@access_info, "Profile_1")
      assert code == 400
      assert parse_onvif_error_type(response) == "ter:NotAuthorized"
    end
  end

  test "pan_tilt coordinates available" do
    response = ONVIFPTZ.pan_tilt_zoom_vector [x: 0.5671, y: 0.9919]
    assert String.contains? response, "PanTilt"
    assert not String.contains? response, "Zoom"
  end

  test "pan_tilt coordinates and zoom available" do
    response = ONVIFPTZ.pan_tilt_zoom_vector [x: 0.5671, y: 0.9919, zoom: 1.0]
    assert String.contains? response, "Zoom"
    assert String.contains? response, "PanTilt"
  end

  test "pan_tilt coordinates available broken but zoom ok" do
    response = ONVIFPTZ.pan_tilt_zoom_vector [x: 0.5671, zoom: 0.9919]
    assert String.contains? response, "Zoom"
    assert not String.contains? response, "PanTilt"
  end

  test "pan_tilt_zoom only zoom available" do
    response = ONVIFPTZ.pan_tilt_zoom_vector [zoom: 0.5671]
    assert String.contains? response, "Zoom"
    assert not String.contains? response, "PanTilt"
  end

  test "pan_tilt_zoom empty" do
    response = ONVIFPTZ.pan_tilt_zoom_vector []
    assert not String.contains? response, "Zoom"
    assert not String.contains? response, "PanTilt"
  end
end
