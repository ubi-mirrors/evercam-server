defmodule EvercamMediaWeb.EmailView do
  use EvercamMedia.Web, :view

  def full_name(user) do
    "#{user.firstname} #{user.lastname}"
  end

  def get_user_name(email) do
    email
    |> User.by_username_or_email
    |> User.get_fullname
  end
end
