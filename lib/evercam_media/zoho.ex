defmodule EvercamMedia.Zoho do
  require Logger

  @zoho_url System.get_env["ZOHO_URL"]
  @zoho_auth_token System.get_env["ZOHO_AUTH_TOKEN"]

  def get_camera(camera_exid) do
    url = "#{@zoho_url}Cameras/search?criteria=(Evercam_ID:equals:#{camera_exid})"
    headers = ["Authorization": "#{@zoho_auth_token}"]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Poison.decode!(body)
        camera = Map.get(json_response, "data") |> List.first
        {:ok, camera}
      {:ok, %HTTPoison.Response{status_code: 204}} -> {:nodata, "Camera does't exits."}
      _ -> {:error, ""}
    end
  end

  def insert_camera(cameras) do
    url = "#{@zoho_url}Cameras"
    headers = ["Authorization": "#{@zoho_auth_token}", "Content-Type": "application/x-www-form-urlencoded"]


    camera_object = create_camera_request(cameras, [])
    request = %{"data" => camera_object}

    case HTTPoison.post(url, Poison.encode!(request), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} -> {:ok, body}
      _ -> {:error}
    end
  end

  def update_camera(cameras, id) do
    url = "#{@zoho_url}Cameras/#{id}"
    headers = ["Authorization": "#{@zoho_auth_token}", "Content-Type": "application/x-www-form-urlencoded"]

    camera_object = create_camera_request(cameras, [])
    request = %{"data" => camera_object}

    case HTTPoison.put(url, Poison.encode!(request), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Poison.decode!(body)
        response = Map.get(json_response, "data") |> List.first
        {:ok, response}
      _ -> {:error}
    end
  end

  def get_contact(email) do
    url = "#{@zoho_url}Contacts/search?criteria=(Email:equals:#{email})"
    headers = ["Authorization": "#{@zoho_auth_token}"]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Poison.decode!(body)
        contact = Map.get(json_response, "data") |> List.first
        {:ok, contact}
      {:ok, %HTTPoison.Response{status_code: 204}} -> {:nodata, "Camera does't exits."}
      _ -> {:error}
    end
  end

  def insert_contact(user) do
    url = "#{@zoho_url}Contacts"
    headers = ["Authorization": "#{@zoho_auth_token}", "Content-Type": "application/x-www-form-urlencoded"]

    contact_xml =
      %{"data" =>
        [%{
          "First_Name" => "#{user.firstname}",
          "Last_Name" => "#{user.lastname}",
          "Email" => "#{user.email}"
        }]
      }

    case HTTPoison.post(url, Poison.encode!(contact_xml), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} ->
        json_response = Poison.decode!(body)
        contact = Map.get(json_response, "data") |> List.first
        {:ok, contact["details"]}
      error -> {:error, error}
    end
  end

  def associate_camera_contact(contact, camera) do
    url = "#{@zoho_url}Cameras_X_Contacts"
    headers = ["Authorization": "#{@zoho_auth_token}", "Content-Type": "application/x-www-form-urlencoded"]

    contact_xml =
      %{ "data" => [%{
          "Description" => "#{camera["Name"]} shared with #{contact["Full_Name"]}",
          "Related_Camera_Sharees" => %{
            "name": camera["Name"],
            "id": camera["id"]
          },
          "Camera_Sharees" => %{
            "name": contact["Full_Name"],
            "id": contact["id"]
          }
        }]
      }

    case HTTPoison.post(url, Poison.encode!(contact_xml), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} -> {:ok, body}
      error -> {:error, error}
    end
  end

  def create_camera_request([camera | rest], camera_json) do
    url_to_nvr = "http://#{Camera.host(camera, "external")}:#{Camera.get_nvr_port(camera)}"
    evercam_type =
      case camera.owner.username do
        "smartcities" -> "Smart Cities"
        _ -> "Construction"
      end
    camera_obj =
      %{
        "Evercam_ID" => "#{camera.exid}",
        "Evercam_Type" => "#{evercam_type}",
        "Name" => "#{camera.name}",
        "Passwords" => "#{Camera.password(camera)}",
        "URL_to_NVR" => "#{url_to_nvr}"
      }

    create_camera_request(rest, List.insert_at(camera_json, -1, camera_obj))
  end
  def create_camera_request([], camera_json), do: camera_json
end
