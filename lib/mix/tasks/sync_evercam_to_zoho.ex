defmodule EvercamMedia.SyncEvercamToZoho do
  alias EvercamMedia.Zoho
  alias EvercamMedia.Repo
  import Ecto.Query
  require Logger

  def sync_cameras(email_or_username) do
    {:ok, _} = Application.ensure_all_started(:evercam_media)

    Logger.info "Start sync cameras to zoho."

    email_or_username
    |> User.by_username_or_email
    |> Camera.for(false)
    |> Zoho.insert_camera

    Logger.info "Camera(s) sync successfully."
  end

  def sync_camera_sharees(email_or_username) do
    user = User.by_username_or_email(email_or_username)
    cameras = Camera.for(user, false)

    Enum.each(cameras, fn(camera) ->
      zoho_camera =
        case Zoho.get_camera(camera.exid) do
          {:ok, zoho_camera} -> zoho_camera
          _ -> %{}
        end

      camera_shares =
        CameraShare
        |> where(user_id: ^camera.id)
        |> preload(:user)
        |> Repo.all

      request_param = create_request_params(camera_shares, zoho_camera, [])
      IO.inspect request_param
    end)
  end

  defp create_request_params([camera_share | rest], zoho_camera, request_param) do
    zoho_contact =
      case Zoho.get_contact(camera_share.user.email) do
        {:ok, zoho_contact} -> zoho_contact
        _ -> %{}
      end

    json_object =
      %{
        "Description" => "#{zoho_camera["Name"]} shared with #{zoho_contact["Full_Name"]}",
        "Related_Camera_Sharees" => %{
          "name": zoho_camera["Name"],
          "id": zoho_camera["id"]
        },
        "Camera_Sharees" => %{
          "name": zoho_contact["Full_Name"],
          "id": zoho_contact["id"]
        }
      }

    create_request_params(rest, zoho_camera, List.insert_at(request_param, -1, json_object))
  end
  defp create_request_params([], _zoho_camera, request_param), do: request_param
end
