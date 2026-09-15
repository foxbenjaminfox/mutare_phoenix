defmodule Demo.PageController do
  @moduledoc """
  Controller actions with explicit response statuses, bodies, redirects, and downloads
  for tests to check.
  """

  @doc "Render a welcome payload with an explicit 200."
  def index(conn, _params) do
    conn
    |> Plug.Conn.put_status(:ok)
    |> Phoenix.Controller.json(%{message: "welcome"})
  end

  @doc "Create a record and respond with 201 Created."
  def create(conn, _params) do
    conn
    |> Plug.Conn.put_status(:created)
    |> Phoenix.Controller.json(%{id: 1})
  end

  @doc "Redirect to the login page with an explicit temporary redirect."
  def login(conn, _params) do
    Phoenix.Controller.redirect(conn, to: "/login", status: :found)
  end

  @doc "Respond to a liveness probe with a fixed text body."
  def ping(conn, _params) do
    Phoenix.Controller.text(conn, "pong")
  end

  @doc "Export the report as a CSV file the browser should save, not display."
  def export(conn, _params) do
    Phoenix.Controller.send_download(conn, {:binary, "id,name\n1,welcome\n"},
      filename: "report.csv",
      disposition: :attachment
    )
  end
end
