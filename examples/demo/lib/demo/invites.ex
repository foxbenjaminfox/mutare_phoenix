defmodule Demo.Invites do
  @moduledoc "Issue invitations carrying a user id, valid for one hour."

  def issue(context, user_id) do
    Phoenix.Token.sign(context, "invite", user_id)
  end

  def accept(context, token) do
    Phoenix.Token.verify(context, "invite", token, max_age: 3600)
  end
end
