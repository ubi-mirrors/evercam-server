defmodule Permission.User do
  def can_view?(requester, user) do
    can_access?("view", requester, user)
  end

  defp can_access?(right, requester, user) do
    is_owner?(requester, user) or has_right?(right, requester, user)
  end

  defp has_right?(right, requester, user) do
    AccessRight.allows?(requester, user, right, "user")
  end

  defp is_owner?(requester, user) do
    user.id == requester.id
  end
end
