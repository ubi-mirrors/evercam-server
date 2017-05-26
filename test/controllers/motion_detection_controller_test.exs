defmodule EvercamMedia.MotionDetectionControllerTest do
  use EvercamMedia.ConnCase

  setup do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id, api_id: UUID.uuid4(:hex), api_key: UUID.uuid4(:hex)})
    user_b = Repo.insert!(%User{firstname: "Smith", lastname: "Marc", username: "smithmarc", email: "smith@dmarc.com", password: "password456", country_id: country.id, api_id: UUID.uuid4(:hex), api_key: UUID.uuid4(:hex)})
    _access_token = Repo.insert!(%AccessToken{user_id: user.id, request: UUID.uuid4(:hex), is_revoked: false})
    camera = Repo.insert!(%Camera{owner_id: user.id, name: "Austin", exid: "austin", is_public: false, config: %{"external_host" => "192.168.1.100", "external_http_port" => "80"}})
    _motion_detection = Repo.insert!(%MotionDetection{camera_id: camera.id, x1: 0, y1: 0, x2: 100, y2: 100, enabled: false, alert_email: false})

    {:ok, user: user, camera: camera, user_b: user_b}
  end

  test 'GET /v1/cameras/:id/apps/motion-detection, returns motion-detection when camera id valid', context do
    response =
      build_conn
      |> get("/v1/cameras/#{context[:camera].exid}/apps/motion-detection?api_id=#{context[:user].api_id}&api_key=#{context[:user].api_key}")

    motion_detection =
      response.resp_body
      |> Poison.decode!
      |> Map.get("motion_detections")
      |> List.first

    assert response.status == 200
    assert motion_detection != nil
  end

  test 'GET /v1/cameras/:id/apps/motion-detection, returns forbidden error when user does not have permissions', context do
    response =
      build_conn
      |> get("/v1/cameras/#{context[:camera].exid}/apps/motion-detection?api_id=#{context[:user_b].api_id}&api_key=#{context[:user_b].api_key}")

    message =
      response.resp_body
      |> Poison.decode!
      |> Map.get("message")

    assert response.status == 403
    assert message == "Forbidden."
  end

  test 'GET /v1/cameras/:id/apps/motion-detection, returns a not found error for a camera that does not exist', context do
    response =
      build_conn
      |> get("/v1/cameras/cameraxyz/apps/motion-detection?api_id=#{context[:user].api_id}&api_key=#{context[:user].api_key}", %{})

    message =
      response.resp_body
      |> Poison.decode!
      |> Map.get("message")

    assert response.status == 404
    assert message == "The cameraxyz camera does not exist."
  end
end
