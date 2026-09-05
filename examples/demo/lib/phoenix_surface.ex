# A minimal stand-in for the slice of `Plug.Conn` / `Phoenix.Controller` the demo uses, so
# the project runs with no real Phoenix dependency. `mutare_plug` and `mutare_phoenix` match
# calls by module *name* (`Plug.Conn`, `Phoenix.Controller`), so the mutations against these
# stand-ins are identical to what they would be against the real modules. It lives outside
# `lib/demo`, so `.mutare.exs`'s `paths: ["lib/demo"]` leaves it unmutated.
defmodule Plug.Conn do
  @moduledoc "Tiny stand-in for `Plug.Conn`."
  defstruct status: nil, halted: false, assigns: %{}, resp_headers: [], resp_body: nil

  def put_status(%__MODULE__{} = conn, status), do: %{conn | status: status}
  def halt(%__MODULE__{} = conn), do: %{conn | halted: true}

  def assign(%__MODULE__{} = conn, key, value),
    do: %{conn | assigns: Map.put(conn.assigns, key, value)}

  def put_resp_header(%__MODULE__{} = conn, key, value),
    do: %{conn | resp_headers: [{key, value} | conn.resp_headers]}
end

defmodule Phoenix.Controller do
  @moduledoc "Tiny stand-in for `Phoenix.Controller`."
  alias Plug.Conn

  @doc "Render a JSON response body, keeping whatever status was set."
  def json(%Conn{} = conn, data), do: %{conn | resp_body: data}

  @doc "Render a plain-text response body, keeping whatever status was set."
  def text(%Conn{} = conn, data), do: %{conn | resp_body: data}

  @doc "Redirect to a local path, keeping the explicit redirect status when present."
  def redirect(%Conn{} = conn, opts) when is_list(opts) do
    %{conn | status: Keyword.get(opts, :status, :found), resp_body: Keyword.fetch!(opts, :to)}
  end

  @doc "Send a binary as a download, naming the file and telling the browser to save or show it."
  def send_download(%Conn{} = conn, {:binary, contents}, opts) do
    disposition = Keyword.get(opts, :disposition, :attachment)
    filename = Keyword.fetch!(opts, :filename)

    conn
    |> Conn.put_resp_header("content-disposition", ~s[#{disposition}; filename="#{filename}"])
    |> Map.put(:resp_body, contents)
  end
end
