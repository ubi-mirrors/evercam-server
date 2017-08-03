defmodule EvercamMediaWeb.ONVIFPTZController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.ONVIFPTZ

  def status(conn, _params) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.get_status("Profile_1") |> respond_default(conn)
  end

  def nodes(conn, _params) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.get_nodes |> respond_default(conn)
  end

  def configurations(conn, _params) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.get_configurations |> respond_default(conn)
  end

  def presets(conn, _params) do
    conn.assigns.onvif_access_info
    |> ONVIFPTZ.get_presets("Profile_1")
    |> case do
      {:ok, response} -> respond_default({:ok, response}, conn)
      _ -> respond_default({:ok, %{"Presets" => []}}, conn)
    end
  end

  def stop(conn, _params) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.stop("Profile_1") |> respond(conn)
  end

  def home(conn, _params) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.goto_home_position("Profile_1") |> respond(conn)
  end

  def sethome(conn, _params) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.set_home_position("Profile_1") |> respond(conn)
  end

  def gotopreset(conn, %{"preset_token" => token}) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.goto_preset("Profile_1", token) |> respond(conn)
  end

  def setpreset(conn, %{"preset_token" => token}) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.set_preset("Profile_1", "", token) |> respond(conn)
  end

  def createpreset(conn, %{"preset_name" => name}) do
    conn.assigns.onvif_access_info |> ONVIFPTZ.set_preset("Profile_1", name) |> respond(conn)
  end

  def continuousmove(conn, %{"direction" => direction}) do
    velocity =
      case direction do
        "left" -> [x: -0.1, y: 0.0]
        "right" -> [x: 0.1, y: 0.0]
        "up" -> [x: 0.0, y: 0.1]
        "down" -> [x: 0.0, y: -0.1]
        _ -> [x: 0.0, y: 0.0]
      end
    conn.assigns.onvif_access_info |> ONVIFPTZ.continuous_move("Profile_1", velocity) |> respond(conn)
  end

  def continuouszoom(conn, %{"mode" => mode}) do
    velocity =
      case mode do
        "in" -> [zoom: 0.01]
        "out" -> [zoom: -0.01]
        _ -> [zoom: 0.0]
      end
    conn.assigns.onvif_access_info |> ONVIFPTZ.continuous_move("Profile_1", velocity) |> respond(conn)
  end

  def relativemove(conn, params) do
    left = Map.get(params, "left", "0") |> String.to_integer
    right = Map.get(params, "right", "0") |> String.to_integer
    up = Map.get(params, "up", "0") |> String.to_integer
    down = Map.get(params, "down", "0") |> String.to_integer
    zoom = Map.get(params, "zoom", "0") |> String.to_integer
    x =
      cond do
        right > left -> right
        true -> -left
      end
    y =
      cond do
        down > up -> down
        true -> -up
      end
    conn.assigns.onvif_access_info |> ONVIFPTZ.relative_move("Profile_1", [x: x / 100.0, y: y / 100.0, zoom: zoom / 100.0]) |> respond(conn)
  end

  defp respond({:ok, response}, conn) do
    conn
    |> put_status(:created)
    |> json(response)
  end

  defp respond({:error, code, response}, conn) do
    conn
    |> put_status(code)
    |> json(response)
  end

  defp respond_default({:ok, response}, conn) do
    conn
    |> json(response)
  end
end
