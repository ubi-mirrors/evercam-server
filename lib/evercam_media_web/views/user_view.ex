defmodule EvercamMediaWeb.UserView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("show.json", %{user: user}) do
    %{
      users: [
        %{
          id: user.username,
          firstname: user.firstname,
          lastname: user.lastname,
          username: user.username,
          email: user.email,
          country: User.get_country_attr(user, :iso3166_a2),
          stripe_customer_id: user.stripe_customer_id,
          created_at: Util.ecto_datetime_to_unix(user.created_at),
          updated_at: Util.ecto_datetime_to_unix(user.updated_at),
          confirmed_at: Util.ecto_datetime_to_unix(user.confirmed_at),
        }
      ]
    }
  end

  def render("credentials.json", %{user: user}) do
    %{
      api_id: user.api_id,
      api_key: user.api_key
    }
  end
end
