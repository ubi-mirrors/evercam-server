defmodule EvercamMediaWeb.Auth do
  def validate("", "", ""), do: :valid
  def validate(api_id, api_key, token) do
    cond do
      user = User.get_by_api_keys(api_id, api_key) -> {:valid, user}
      token = User.get_user_from_token(token) -> {:valid, token}
      true -> :invalid
    end
  end
end
