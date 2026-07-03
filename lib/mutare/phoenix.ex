defmodule Mutare.Phoenix do
  @moduledoc """
  Custom [Mutare](https://hex.pm/packages/mutare) mutators for the Phoenix request
  surface — the `Plug.Conn` / `Phoenix.Controller` calls a plug or controller action
  performs.

  ## Usage

  Add `mutare_phoenix` to your deps, then list its families in `.mutare.exs`. Setting
  `:mutators` replaces Mutare's default set, so include the `:builtins` family to keep the
  built-ins on:

      # .mutare.exs
      [mutators: [:builtins] ++ Mutare.Phoenix.all()]

  `all/0` returns this package's six families:

    * `Mutare.Phoenix.Plug` — `:plug_halt`, removes `Plug.Conn.halt/1`.
    * `Mutare.Phoenix.Response` — `:http_status`, swaps the atom status of
      `Plug.Conn.put_status/2`, `send_resp/3`, `resp/3`, `send_chunked/2`, and
      `send_file/3,4,5` for a same-family sibling.
    * `Mutare.Phoenix.Redirect` — `:redirect_status`, swaps the explicit atom
      `:status` option of `Phoenix.Controller.redirect/2` for a redirect-status sibling.
    * `Mutare.Phoenix.Session` — `:plug_session`, removes session mutations.
    * `Mutare.Phoenix.Header` — `:resp_header`, removes response-header mutations.
    * `Mutare.Phoenix.Cookie` — `:resp_cookie`, removes response-cookie mutations and
      flips explicit `:same_site` values.

  Each family matches its call written directly (`Plug.Conn.halt(conn)`), aliased, or
  bare-imported (`halt(conn)`, the form `use MyAppWeb, :controller` produces).

  The package also registers defensive `Mutare.MacroRouting` entries through the enabled
  families so Phoenix compile-time macros do not poison the metamutant build. Today that means
  skipping `Phoenix.Router` DSL arguments and `Phoenix.Component.sigil_H/2` HEEx sigil
  arguments.
  """

  # Mutators pattern-match module *names* (`Plug.Conn`, `Phoenix.Controller`,
  # `Phoenix.Router`), so this package depends on neither `phoenix` nor `plug` — resolution
  # happens in the target project, where they are present. LiveView is out of scope; it is
  # handled by the companion `mutare_phoenix_live_view`.
  @families [
    Mutare.Phoenix.Plug,
    Mutare.Phoenix.Response,
    Mutare.Phoenix.Redirect,
    Mutare.Phoenix.Session,
    Mutare.Phoenix.Header,
    Mutare.Phoenix.Cookie
  ]

  @doc """
  This package's six mutator families, for splicing into `:mutators` (see the module
  docs for the `:builtins` pairing).

      iex> Mutare.Phoenix.all() == [
      ...>   Mutare.Phoenix.Plug,
      ...>   Mutare.Phoenix.Response,
      ...>   Mutare.Phoenix.Redirect,
      ...>   Mutare.Phoenix.Session,
      ...>   Mutare.Phoenix.Header,
      ...>   Mutare.Phoenix.Cookie
      ...> ]
      true
  """
  @spec all() :: [module()]
  def all, do: @families
end
