# A minimal stand-in for the slice of `Plug.Conn` / `Phoenix.Controller` the demo uses, so
# the project runs with no real Phoenix dependency. `mutare_phoenix` matches calls by module
# *name* (`Plug.Conn`, `Phoenix.Controller`), so the mutations against these stand-ins are
# identical to what they would be against the real modules. It lives outside `lib/demo`, so
# `.mutare.exs`'s `paths: ["lib/demo"]` leaves it unmutated.
defmodule Plug.Conn do
  @moduledoc "Tiny stand-in for `Plug.Conn`."
  defstruct status: nil, halted: false, assigns: %{}, resp_body: nil

  def put_status(%__MODULE__{} = conn, status), do: %{conn | status: status}
  def halt(%__MODULE__{} = conn), do: %{conn | halted: true}

  def assign(%__MODULE__{} = conn, key, value),
    do: %{conn | assigns: Map.put(conn.assigns, key, value)}
end

defmodule Phoenix.Controller do
  @moduledoc "Tiny stand-in for `Phoenix.Controller`."
  alias Plug.Conn

  @doc "Render a response body, keeping whatever status was set."
  def json(%Conn{} = conn, data), do: %{conn | resp_body: data}
end
