defmodule Mutare.Phoenix do
  @moduledoc """
  Custom [Mutare](https://hex.pm/packages/mutare) mutators for the Phoenix controller
  surface — the `Phoenix.Controller` calls a controller action performs on the conn — plus
  the defensive macro routing that keeps Phoenix's compile-time macros from poisoning the
  metamutant build.

  This package builds on `mutare_plug` the way `phoenix` builds on `plug`: it depends on it,
  so the `Plug.Conn` families (`Mutare.Plug.all/0`) are on your code path too, ready to
  compose.

  ## Usage

  Add `mutare_phoenix` to your deps, then list the families in `.mutare.exs` and this module
  under `:extensions`. Setting `:mutators` replaces Mutare's default set, so include the
  `:builtins` family to keep the built-ins on:

      # .mutare.exs
      [
        mutators: [:builtins] ++ Mutare.Plug.all() ++ Mutare.Phoenix.all(),
        extensions: [Mutare.Phoenix]
      ]

  `all/0` returns this package's families:

    * `Mutare.Phoenix.Redirect` — `:redirect_status`, swaps the explicit atom
      `:status` option of `Phoenix.Controller.redirect/2` for a redirect-status sibling.

  It does **not** include the `mutare_plug` families; compose `Mutare.Plug.all/0` explicitly
  as shown above. Each family matches its call written directly
  (`Phoenix.Controller.redirect(conn, ...)`), aliased, or bare-imported
  (`redirect(conn, ...)`, the form `use MyAppWeb, :controller` produces).

  ## The `:extensions` entry

  This module is also a `Mutare.MacroRouting` extension. Listed under `:extensions`, it
  registers Phoenix's compile-time-only macros as `:skip`, so Mutare leaves their arguments
  unmutated:

    * the `Phoenix.Router` DSL (`get`/`post`/`scope`/…), because route definitions run once
      at compile time under Mutare's compile-once model — a mutation there could never
      activate;
    * `Phoenix.Component.sigil_H/2` (`~H`), because HEEx sigil arguments must remain
      compile-time literals — left unregistered, Mutare's imported-call witness would splice
      an unreachable `sigil_H(arg1, arg2)` that Phoenix rejects at compile time, sinking the
      whole metamutant build before poison recovery can isolate a single mutant.

  Mutations *around* a `~H` expression (for example a `render/1` `:return_value` mutant)
  remain available; only the sigil's own arguments are opaque.
  """
  @behaviour Mutare.MacroRouting

  # Mutators pattern-match module *names* (`Phoenix.Controller`, `Phoenix.Router`,
  # `Phoenix.Component`), so this package depends on neither `phoenix` nor `plug` —
  # resolution happens in the target project, where they are present. The `Plug.Conn`
  # surface is the base `mutare_plug`; LiveView is the companion `mutare_phoenix_live_view`.
  @families [Mutare.Phoenix.Redirect]

  # The `Phoenix.Router` DSL, registered `:skip` so core leaves route definitions raw.
  # `:any` arity covers every form (`get/3`, `get/4`, `scope/2..4`, …).
  @router_macros [
    :get,
    :post,
    :put,
    :patch,
    :delete,
    :options,
    :head,
    :connect,
    :trace,
    :match,
    :forward,
    :resources,
    :scope,
    :pipeline,
    :pipe_through
  ]

  # `~H` compiles to `Phoenix.Component.sigil_H/2`, whose arguments must stay literal.
  # Leaving it unregistered lets Mutare's imported-call witness generate an unreachable
  # `sigil_H(arg1, arg2)`; macros still expand in unreachable code, so Phoenix raises before
  # poison recovery can identify a single mutant. Routing both arguments `:skip` drops that
  # witness and keeps the sigil payload opaque while mutations around the whole expression
  # (for example `:return_value`) remain available.
  @component_macros [{Phoenix.Component, :sigil_H, 2, :skip}]

  @doc """
  This package's mutator families, for splicing into `:mutators` (see the module docs for
  the `Mutare.Plug.all/0` and `:builtins` pairing).

      iex> Mutare.Phoenix.all()
      [Mutare.Phoenix.Redirect]
  """
  @spec all() :: [module()]
  def all, do: @families

  # Defensive, not a route mutator: a router body is compile-time code that runs once as
  # mutant 0, so route/verb/pipeline mutations can never activate under Mutare's compile-once
  # model. Skipping the DSL keeps core from wasting mutant ids on it. Plug *function* bodies
  # (`def call/2`) and controller actions are ordinary runtime code and are still mutated.
  @impl Mutare.MacroRouting
  @spec macro_routes() :: [Mutare.MacroRouting.route()]
  def macro_routes do
    Enum.map(@router_macros, &{Phoenix.Router, &1, :any, :skip}) ++ @component_macros
  end
end
