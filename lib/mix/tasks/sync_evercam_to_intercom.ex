defmodule EvercamMedia.SyncEvercamToIntercom do
  require Logger

  @intercom_url System.get_env["INTERCOM_URL"]
  @intercom_token System.get_env["INTERCOM_ACCESS_TOKEN"]

  def get_users(next_page \\ nil) do
    api_url =
      case next_page do
        url when url in [nil, ""] -> "#{@intercom_url}"
        next_url -> next_url
      end

    headers = ["Authorization": "Bearer #{@intercom_token}", "Accept": "Accept:application/json"]
    {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(api_url, headers)
    users = Poison.decode!(body) |> Map.get("users")
    pages = Poison.decode!(body) |> Map.get("pages")
    verify_user(users, Map.get(pages, "next"))
  end

  def verify_user([intercom_user | rest], next_url) do
    intercom_email = Map.get(intercom_user, "email")
    user_id = Map.get(intercom_user, "user_id")
    Logger.info "Verifing user email: #{intercom_email}, user_id: #{user_id}"
    case User.by_username_or_email(intercom_email) do
      nil ->
        Logger.info "User deleted from evercam. email: #{intercom_email}"
        EvercamMedia.Intercom.delete_user(intercom_email, "email")
      %User{} = user -> Logger.info "Intercom user exists in Evercam. email: #{user.email}"
    end
    verify_user(rest, next_url)
  end
  def verify_user([], nil), do: Logger.info "Users sync completed."
  def verify_user([], next_url) do
    Logger.info "Start next page users. URL: #{next_url}"
    get_users(next_url)
  end
end
