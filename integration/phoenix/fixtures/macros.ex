defmodule RoutedController do
  use Phoenix.Controller, formats: []

  def ping(conn, _params), do: text(conn, "pong")
end

defmodule ContractRouter do
  use Phoenix.Router, helpers: false

  scope "/api" do
    get("/ping", RoutedController, :ping)
  end
end

defmodule ContractComponent do
  import Phoenix.Component

  def render(assigns) do
    ~H"""
    <p>{@name}</p>
    """
  end
end
