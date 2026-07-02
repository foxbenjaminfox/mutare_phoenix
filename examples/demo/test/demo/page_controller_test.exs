defmodule Demo.PageControllerTest do
  use ExUnit.Case

  alias Demo.PageController

  # index is pinned down: it asserts the exact 200, so swapping :ok for any other 2xx is
  # killed.
  test "index renders a welcome body with 200" do
    conn = PageController.index(%Plug.Conn{}, %{})
    assert conn.status == :ok
    assert conn.resp_body == %{message: "welcome"}
  end

  # create asserts only the *body*, never the status — so swapping :created for another
  # success (:ok / :accepted) is invisible. A missing status assertion: `:http_status`
  # survives.
  test "create returns the new record" do
    conn = PageController.create(%Plug.Conn{}, %{})
    assert conn.resp_body == %{id: 1}
  end

  # login asserts only the redirect target, never the redirect status — so changing
  # :found to another valid redirect status is invisible. A missing redirect-status
  # assertion: :redirect_status survives.
  test "login redirects to the login page" do
    conn = PageController.login(%Plug.Conn{}, %{})
    assert conn.resp_body == "/login"
  end
end
