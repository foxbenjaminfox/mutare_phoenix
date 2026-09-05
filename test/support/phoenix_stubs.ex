# Minimal stand-ins for the `Plug.Conn` / `Phoenix.Controller` / `Phoenix.Router` /
# `Phoenix.Component` surface, loaded only in the test environment. `mutare_phoenix` depends
# on neither `plug` nor `phoenix` (it matches on module *names*), so these tiny modules let
# the test suite:
#
#   * resolve a **bare imported** call (`import Phoenix.Controller; redirect(conn, ...)`) —
#     the form `use MyAppWeb, :controller` produces — which `Mutare.Transform.Imports`
#     resolves by reflecting on the imported module's exported arities, so the module must be
#     loadable;
#   * compile a generated metamutant without "undefined function" warnings.
#
# They carry no behaviour worth testing — the mutators operate on source AST, not a live
# conn — so the bodies are the smallest thing that type-checks as `conn -> conn`. The
# `Plug.Conn` slice is only what the cross-package integration test and the
# `Phoenix.Controller` stand-in reach for; `mutare_plug` carries the full stand-in.
defmodule Plug.Conn do
  @moduledoc false
  defstruct status: nil,
            halted: false,
            assigns: %{},
            resp_headers: [],
            resp_body: nil,
            resp_cookies: %{}

  def put_status(%__MODULE__{} = conn, status), do: %{conn | status: status}
  def halt(%__MODULE__{} = conn), do: %{conn | halted: true}

  def assign(%__MODULE__{} = conn, key, value),
    do: %{conn | assigns: Map.put(conn.assigns, key, value)}

  def put_resp_content_type(%__MODULE__{} = conn, type),
    do: %{conn | resp_headers: [{"content-type", type} | conn.resp_headers]}

  def send_resp(%__MODULE__{} = conn, status, body),
    do: %{conn | status: status, resp_body: body}

  def put_session(%__MODULE__{} = conn, key, value),
    do: assign(conn, :session, Map.put(Map.get(conn.assigns, :session, %{}), key, value))

  def put_resp_header(%__MODULE__{} = conn, key, value),
    do: %{conn | resp_headers: [{key, value} | List.keydelete(conn.resp_headers, key, 0)]}

  def put_resp_cookie(%__MODULE__{} = conn, key, value, opts),
    do: %{conn | resp_cookies: Map.put(conn.resp_cookies, key, {value, opts})}
end

defmodule Phoenix.Controller do
  @moduledoc false
  alias Plug.Conn

  def put_flash(%Conn{} = conn, key, message),
    do: Conn.assign(conn, :flash, Map.put(Map.get(conn.assigns, :flash, %{}), key, message))

  def json(%Conn{} = conn, data), do: Conn.send_resp(conn, conn.status || 200, data)
  def text(%Conn{} = conn, data), do: Conn.send_resp(conn, conn.status || 200, data)
  def html(%Conn{} = conn, data), do: Conn.send_resp(conn, conn.status || 200, data)

  def send_download(conn, kind, opts \\ [])

  def send_download(%Conn{} = conn, {:file, path}, opts),
    do: download(conn, Keyword.get(opts, :filename, Path.basename(path)), opts, path)

  def send_download(%Conn{} = conn, {:binary, contents}, opts),
    do: download(conn, Keyword.fetch!(opts, :filename), opts, contents)

  defp download(conn, filename, opts, body) do
    disposition = Keyword.get(opts, :disposition, :attachment)

    conn
    |> Conn.put_resp_header("content-disposition", ~s[#{disposition}; filename="#{filename}"])
    |> Conn.send_resp(conn.status || 200, body)
  end

  def redirect(%Conn{} = conn, opts) when is_list(opts) do
    conn
    |> Conn.put_status(Keyword.get(opts, :status, :found))
    |> Conn.put_resp_content_type("text/html")
    |> Map.put(:resp_body, Keyword.get(opts, :to) || Keyword.get(opts, :external))
  end
end

defmodule Phoenix.Router do
  @moduledoc false
  # Only needs to *exist* as a module-key target for the `macro_routes/0` `:skip` registration
  # test; the registration is purely syntactic, so no DSL macros are required here.
end

defmodule Phoenix.Component do
  @moduledoc false
  # A tiny literal-only `~H` stand-in. It intentionally accepts only real sigil syntax,
  # not `sigil_H(arg1, arg2)`, so tests cover Mutare's imported-macro witness hazard.
  defmacro sigil_H({:<<>>, _meta, _segments}, []), do: quote(do: {:safe, ""})
end
