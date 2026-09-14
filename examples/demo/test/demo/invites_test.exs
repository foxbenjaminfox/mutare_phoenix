defmodule Demo.InvitesTest do
  use ExUnit.Case, async: true

  alias Demo.Invites

  @context "demo-only-secret-key-base"

  test "issuing an invitation produces a token" do
    assert is_binary(Invites.issue(@context, 7))
  end

  test "a fresh signed invitation is accepted" do
    # Independent fixture: exercises the reader without checking the issuing site.
    token = Phoenix.Token.sign(@context, "invite", 7)
    assert {:ok, _user_id} = Invites.accept(@context, token)
  end
end
