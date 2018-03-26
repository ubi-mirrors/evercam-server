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
    camera_ids = Enum.map(cameras, fn(camera) -> camera.id end)

    CameraShare
    |> where([cs], cs.user_id in ^camera_ids)
    |> Repo.all

    # {users, emails} =
    #   Camera
    #   |> where([cam], cam.owner_id == ^user.id)
    #   |> preload(:owner)
    #   |> preload(:shares)
    #   |> preload([shares: :user])
    #   |> Repo.all
    #   |> Enum.reduce({[], []}, fn(camera, {all_sharees, all_emails}) ->
    #     {sharees, sharee_emails_list} =
    #       camera.shares
    #       |> Enum.reduce({[], all_emails}, fn(camera_share, {sharee_list, sharee_emails}) ->
    #         # Logger.info "Start Contact sync: [#{camera_share.user.email}]"
    #         case Enum.member?(sharee_emails, camera_share.user.email) do
    #           true ->
    #             Logger.info "Duplicate Email: #{camera_share.user.email}"
    #             {sharee_list, sharee_emails}
    #           false ->
    #             {[camera_share.user | sharee_list], [camera_share.user.email | sharee_emails]}
    #         end
    #         # case Zoho.get_contact(camera_share.user.email) do
    #         #   {:ok, _} -> sharee_list
    #         #   _ -> [camera_share.user | sharee_list]
    #         # end
    #       end)
    #     {[sharees | all_sharees], [sharee_emails_list | all_emails]}
    #   end)
    # IO.inspect Enum.coun(users)
    # Enum.each(users, fn(user) ->
    #   Logger.debug user.email
    # end)
  end
end
