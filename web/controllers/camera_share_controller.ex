defmodule EvercamMedia.CameraShareController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.CameraShareView
  alias EvercamMedia.CameraShareRequestView
  alias EvercamMedia.Intercom

  def show(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)
    user = User.by_username_or_email(params["user_id"])

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- user_exists(conn, params["user_id"], user),
         :ok <- user_can_list(conn, current_user, camera, params["user_id"])
    do
      shares =
        cond do
          user == nil && exid == "evercam-remembrance-camera" ->
            []
          user != nil && current_user != nil ->
            CameraShare.user_camera_share(camera, user)
          current_user != nil && Permission.Camera.can_edit?(current_user, camera) ->
            CameraShare.camera_shares(camera)
          true ->
            []
        end
        conn
        |> render(CameraShareView, "index.json", %{camera_shares: shares, camera: camera, user: current_user})
    end
  end

  def create(conn, params) do
    caller = conn.assigns[:current_user]
    camera = Camera.get_full(params["id"])
    sharee = User.by_username_or_email(params["email"])

    with :ok <- camera_exists(conn, params["id"], camera),
         :ok <- user_can_create_share(conn, caller, camera)
    do
      requester_ip = user_request_ip(conn)
      if sharee do
        case CameraShare.create_share(camera, sharee, caller, params["rights"], params["message"]) do
          {:ok, camera_share} ->
            unless caller == sharee do
              send_email_notification(caller, camera, sharee.email, camera_share.message)
            end
            Camera.invalidate_user(sharee)
            Camera.invalidate_camera(camera)
            CameraActivity.log_activity(caller, camera, "shared", %{with: sharee.email, ip: requester_ip})
            conn |> put_status(:created) |> render(CameraShareView, "show.json", %{camera_share: camera_share})
          {:error, changeset} ->
            render_error(conn, 400, Util.parse_changeset(changeset))
        end
      else
        case CameraShareRequest.create_share_request(camera, params["email"], caller, params["rights"], params["message"]) do
          {:ok, camera_share_request} ->
            send_email_notification(caller, camera, params["email"], camera_share_request.message, camera_share_request.key)
            CameraActivity.log_activity(caller, camera, "shared", %{with: params["email"], ip: requester_ip})
            Intercom.intercom_activity(Application.get_env(:evercam_media, :create_intercom_user), get_user_model(params["email"]), get_user_agent(conn), requester_ip, "Shared-Non-Registered")
            conn |> put_status(:created) |> render(CameraShareRequestView, "show.json", %{camera_share_requests: camera_share_request})
          {:error, changeset} ->
            render_error(conn, 400, Util.parse_changeset(changeset))
        end
      end
    end
  end

  def update(conn, %{"id" => exid, "email" => email, "rights" => rights}) do
    caller = conn.assigns[:current_user]
    camera = Camera.get_full(exid)
    sharee = User.by_username_or_email(email)

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- caller_has_permission(conn, caller, camera),
         :ok <- sharee_exists(conn, email, sharee),
         {:ok, camera_share} <- share_exists(conn, sharee, camera)
    do
      share_changeset = CameraShare.changeset(camera_share, %{rights: rights})
      if share_changeset.valid? do
        CameraShare.update_share(sharee, camera, rights)
        CameraActivity.log_activity(caller, camera, "updated share", %{with: sharee.email, ip: user_request_ip(conn)})
        Camera.invalidate_user(sharee)
        Camera.invalidate_camera(camera)
        camera_share =
          camera_share
          |> Repo.preload([camera: :access_rights], force: true)
          |> Repo.preload([camera: [access_rights: :access_token]], force: true)
        conn
        |> render(CameraShareView, "show.json", %{camera_share: camera_share})
      else
        render_error(conn, 400, Util.parse_changeset(share_changeset))
      end
    end
  end

  def delete(conn, %{"id" => exid, "email" => email}) do
    caller = conn.assigns[:current_user]
    camera = Camera.get_full(exid)
    sharee = User.by_username_or_email(email)

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- sharee_exists(conn, email, sharee),
         :ok <- user_can_delete_share(conn, caller, sharee, camera),
         {:ok, _share} <- share_exists(conn, sharee, camera)
    do
      CameraShare.delete_share(sharee, camera)
      Camera.invalidate_user(sharee)
      Camera.invalidate_camera(camera)
      CameraActivity.log_activity(caller, camera, "stopped sharing", %{with: sharee.email, ip: user_request_ip(conn)})
      json(conn, %{})
    end
  end

  def shared_users(conn, params) do
    caller = conn.assigns[:current_user]

    cond do
      !caller ->
        render_error(conn, 401, "Unauthorized.")
      params["camera_id"] == "evercam-remembrance-camera" -> json(conn, %{})
      true ->
        shared_users =
          caller.id
          |> CameraShare.shared_users(params["camera_id"])
          |> Enum.map(fn(u) -> %{email: u.user.email, name: User.get_fullname(u.user)} end)
          |> Enum.sort
          |> Enum.uniq
        json(conn, shared_users)
    end
  end

  defp camera_exists(conn, camera_exid, nil), do: render_error(conn, 404, "The #{camera_exid} camera does not exist.")
  defp camera_exists(_conn, _camera_exid, _camera), do: :ok

  defp user_exists(_conn, nil, nil), do: :ok
  defp user_exists(conn, user_id, nil), do: render_error(conn, 404, "User '#{user_id}' does not exist.")
  defp user_exists(_conn, _user_id, _user), do: :ok

  defp caller_has_permission(conn, user, camera) do
    if Permission.Camera.can_edit?(user, camera) do
      :ok
    else
      render_error(conn, 401, "Unauthorized.")
    end
  end

  defp user_can_list(_conn, _user, _camera, nil), do: :ok
  defp user_can_list(conn, user, camera, user_id) do
    user_id = String.downcase(user_id)

    if !Permission.Camera.can_list?(user, camera) && (user.email != user_id && user.username != user_id) do
      render_error(conn, 401, "Unauthorized.")
    else
      :ok
    end
  end

  defp user_can_create_share(conn, caller, camera) do
    if Permission.Camera.can_list?(caller, camera), do: :ok, else: render_error(conn, 401, "Unauthorized.")
  end

  defp user_can_delete_share(conn, caller, sharee, camera) do
    cond do
      Permission.Camera.can_list?(caller, camera) -> :ok
      caller == sharee -> :ok
      true -> render_error(conn, 401, "Unauthorized.")
    end
  end

  defp sharee_exists(conn, email, nil), do: render_error(conn, 404, "Sharee '#{email}' not found.")
  defp sharee_exists(_conn, _email, _sharee), do: :ok

  defp share_exists(conn, sharee, camera) do
    case CameraShare.by_user_and_camera(camera.id, sharee.id) do
      nil -> render_error(conn, 404, "Share not found.")
      %CameraShare{} = camera_share -> {:ok, camera_share}
    end
  end

  defp send_email_notification(user, camera, to_email, message) do
    try do
      Task.start(fn ->
        EvercamMedia.UserMailer.camera_shared_notification(user, camera, to_email, message)
      end)
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  defp send_email_notification(user, camera, to_email, message, share_request_key) do
    try do
      Task.start(fn ->
        EvercamMedia.UserMailer.camera_share_request_notification(user, camera, to_email, message, share_request_key)
      end)
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  defp get_user_model(email) do
    %User{
      username: "",
      firstname: "",
      lastname: "",
      email: email,
      created_at: Ecto.DateTime.utc
    }
  end
end
