# Minimal stand-ins for the `Plug.Conn` / `Phoenix.Controller` / `Phoenix.Router` /
# `Phoenix.Component` / `Phoenix.Channel` / `Phoenix.PubSub` / `Phoenix.Token` surface, loaded
# only in the test environment. `mutare_phoenix` depends on neither `plug` nor `phoenix` (it
# matches on module *names*), so these tiny modules let the test suite:
#
#   * resolve a **bare imported** call (`import Phoenix.Controller; redirect(conn, ...)`) —
#     the form `use MyAppWeb, :controller` produces — which `Mutare.Transform.Imports`
#     resolves by reflecting on the imported module's exported arities, so the module must be
#     loadable;
#   * surface a `use`-injected `@behaviour Phoenix.Channel` (the `:channel_reply` gate) — the
#     `__using__` injects it the way the real `Phoenix.Channel` does, so `Mutare.Transform.Uses`
#     can harvest it in-process;
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
  # Only needs to *exist* as a module-key target for the `call_routes/0` `:skip` registration
  # test; the registration is purely syntactic, so no DSL macros are required here.
end

defmodule Phoenix.Component do
  @moduledoc false
  # A tiny literal-only `~H` stand-in. It intentionally accepts only real sigil syntax,
  # not `sigil_H(arg1, arg2)`, so tests cover Mutare's imported-macro witness hazard.
  defmacro sigil_H({:<<>>, _meta, _segments}, []), do: quote(do: {:safe, ""})
end

# The channel surface. `use Phoenix.Channel` injects the behaviour (the `:channel_reply` gate)
# and imports the module, so a bare `broadcast(socket, ...)` / `push(socket, ...)` resolves.
defmodule Phoenix.Channel do
  @moduledoc false

  @callback join(topic :: binary(), payload :: map(), socket :: term()) :: term()
  @callback handle_in(event :: binary(), payload :: map(), socket :: term()) :: term()
  @callback handle_out(event :: binary(), payload :: map(), socket :: term()) :: term()
  @callback handle_info(msg :: term(), socket :: term()) :: term()

  @optional_callbacks join: 3, handle_in: 3, handle_out: 3, handle_info: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Phoenix.Channel
      import Phoenix.Channel
    end
  end

  # The outbound-message surface (`:channel_message`): every real arity, none returning the
  # socket — `:ok` stands in for the `:ok | {:error, term}` the real calls return.
  def broadcast(_socket, _event, _message), do: :ok
  def broadcast!(_socket, _event, _message), do: :ok
  def broadcast_from(_socket, _event, _message), do: :ok
  def broadcast_from!(_socket, _event, _message), do: :ok
  def push(_socket, _event, _message), do: :ok
  def reply(_socket_ref, _reply), do: :ok
  def socket_ref(socket), do: socket
end

# The `Phoenix.PubSub` surface (`:pubsub`): every real arity, each collapsing to the `:ok`
# the removal stands in for. Only the arities matter here — a bare-imported call resolves
# against them, and the arity guard is what the wrong-arity tests exercise.
defmodule Phoenix.PubSub do
  @moduledoc false

  def subscribe(_pubsub, _topic), do: :ok
  def subscribe(_pubsub, _topic, _opts), do: :ok
  def unsubscribe(_pubsub, _topic), do: :ok
  def broadcast(_pubsub, _topic, _message), do: :ok
  def broadcast(_pubsub, _topic, _message, _dispatcher), do: :ok
  def broadcast!(_pubsub, _topic, _message), do: :ok
  def broadcast!(_pubsub, _topic, _message, _dispatcher), do: :ok
  def broadcast_from(_pubsub, _from, _topic, _message), do: :ok
  def broadcast_from(_pubsub, _from, _topic, _message, _dispatcher), do: :ok
  def broadcast_from!(_pubsub, _from, _topic, _message), do: :ok
  def broadcast_from!(_pubsub, _from, _topic, _message, _dispatcher), do: :ok
  def local_broadcast(_pubsub, _topic, _message), do: :ok
  def local_broadcast(_pubsub, _topic, _message, _dispatcher), do: :ok
  def local_broadcast_from(_pubsub, _from, _topic, _message), do: :ok
  def local_broadcast_from(_pubsub, _from, _topic, _message, _dispatcher), do: :ok
  def direct_broadcast(_node, _pubsub, _topic, _message), do: :ok
  def direct_broadcast(_node, _pubsub, _topic, _message, _dispatcher), do: :ok
  def direct_broadcast!(_node, _pubsub, _topic, _message), do: :ok
  def direct_broadcast!(_node, _pubsub, _topic, _message, _dispatcher), do: :ok
end

# The `Phoenix.Token` surface (`:token`): the four calls at both real arities. Each returns
# something of the real call's shape — a binary from the minters, an `{:ok, data}` from the
# readers — so a generated metamutant type-checks; nothing here signs anything.
defmodule Phoenix.Token do
  @moduledoc false

  def sign(_context, _salt, data), do: :erlang.term_to_binary(data)
  def sign(_context, _salt, data, _opts), do: :erlang.term_to_binary(data)
  def encrypt(_context, _secret, data), do: :erlang.term_to_binary(data)
  def encrypt(_context, _secret, data, _opts), do: :erlang.term_to_binary(data)
  def verify(_context, _salt, token), do: {:ok, :erlang.binary_to_term(token)}
  def verify(_context, _salt, token, _opts), do: {:ok, :erlang.binary_to_term(token)}
  def decrypt(_context, _secret, token), do: {:ok, :erlang.binary_to_term(token)}
  def decrypt(_context, _secret, token, _opts), do: {:ok, :erlang.binary_to_term(token)}
end
