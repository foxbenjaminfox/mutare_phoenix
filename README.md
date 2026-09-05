# Mutare Phoenix

Custom [Mutare](https://hex.pm/packages/mutare) mutators for the **Phoenix controller surface** —
the `Phoenix.Controller` calls a controller action performs on the conn — plus the defensive
macro routing that keeps Phoenix's compile-time macros (the `Phoenix.Router` DSL, `~H`) from
poisoning the metamutant build.

A controller action returns a *transformed conn*, so its whole contract is **which
conn-transforming call ran** — the status it set, where it redirected, whether it halted.
These are exactly the calls a suite tends to under-assert: a test that checks "something
happened" but not *which* transformation leaves a gap. `mutare_phoenix` turns each such gap
into a located [Mutare](https://hex.pm/packages/mutare) survivor.

It **builds on** [`mutare_plug`](https://hex.pm/packages/mutare_plug) (the `Plug.Conn`
families — halt, status, session, header, cookie, body) the way `phoenix` builds on `plug`:
it depends on it, so those families are on your code path too, ready to compose.

## The families

`Mutare.Phoenix.all/0` returns three `Phoenix.Controller` families:

| Family | Name | Mutation | The gap a survivor exposes |
| --- | --- | --- | --- |
| `Mutare.Phoenix.Redirect` | `:redirect_status` | swaps the explicit atom `status:` option of `Phoenix.Controller.redirect/2` for a redirect-status sibling (`:found → :see_other`, `:moved_permanently → :permanent_redirect`) | no test pins the exact redirect status |
| `Mutare.Phoenix.Body` | `:controller_body` | blanks the body argument of `Phoenix.Controller.json/2` to `%{}` and of `text/2` / `html/2` to `""` | no test reads the rendered body |
| `Mutare.Phoenix.Download` | `:download_disposition` | flips the explicit `disposition:` option of `Phoenix.Controller.send_download/3` between `:attachment` and `:inline` | no test pins whether the browser is told to save or display the file |

Each family matches its call written directly (`Phoenix.Controller.redirect(conn, ...)`),
aliased, or bare-imported (`redirect(conn, ...)`, the form `use MyAppWeb, :controller`
produces). The option families only mutate an explicit literal atom: redirects and
downloads that rely on Phoenix's default, integer statuses, and variable values are left to
other families or skipped. `render/3` is out of scope for `:controller_body` — its argument
names a template, not a body.

The `Plug.Conn` side of a controller action — `put_status`, `send_resp`, `put_session`,
`put_resp_header`, `put_resp_cookie`, `halt` — is the base package's six families,
[`Mutare.Plug.all/0`](https://hexdocs.pm/mutare_plug).

## The `:extensions` entry

`Mutare.Phoenix` is also a `Mutare.MacroRouting` extension. Listed under `:extensions`, it
registers Phoenix's compile-time-only macros as `:skip`, so their arguments are left
unmutated: the `Phoenix.Router` DSL (`get`/`post`/`scope`/…), because route definitions run
once at compile time under Mutare's compile-once model and a mutation there could never
activate; and `Phoenix.Component.sigil_H/2` (`~H`), because HEEx sigil arguments must remain
compile-time literals — left unregistered, Mutare's imported-call witness would splice an
unreachable `sigil_H(arg1, arg2)` that Phoenix rejects at compile time, sinking the whole
metamutant build. Mutations *around* a `~H` expression, such as a `render/1` return-value
mutant, remain available.

## Usage

`mutare_phoenix` rides on the [Mutare](https://hex.pm/packages/mutare) engine and builds on
`mutare_plug`, so add them as `:dev`/`:test` dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:mutare, "~> 0.1", only: [:dev, :test], runtime: false},
    {:mutare_plug, "~> 0.1", only: [:dev, :test], runtime: false},
    {:mutare_phoenix, "~> 0.1", only: [:dev, :test], runtime: false}
  ]
end
```

Then list the families in `.mutare.exs`, and `Mutare.Phoenix` under `:extensions`. Setting
`:mutators` **replaces** Mutare's default set, so include the `:builtins` family to keep the
built-ins on:

```elixir
# .mutare.exs
[
  mutators: [:builtins] ++ Mutare.Plug.all() ++ Mutare.Phoenix.all(),
  extensions: [Mutare.Phoenix]
]
```

`all/0` returns only this package's families — it does **not** include the `mutare_plug`
ones, so compose `Mutare.Plug.all/0` explicitly as shown. Run it the usual way:

```
mix mutare
```

## Why not the built-in atom mutators?

In a status position, Mutare's built-in atom swaps (`:ok → :error` / `:mutare`) produce a
value that **crashes** — an uninformative kill that tells you nothing about test quality.
`:redirect_status` and `:download_disposition` swap to *valid* siblings (Phoenix rejects any
disposition other than `:attachment` / `:inline`), so a survivor means a genuine missing
assertion rather than a crash, and Mutare's overlap pruning drops the redundant crashing
leaves at the same range. `:controller_body` works the same way for a literal `text` / `html`
body: its whole-call blank covers the string node, so the built-in string family's sentinel
leaves there are pruned automatically and one clean "is the body read?" mutant remains.

## Example

[`examples/demo`](https://github.com/foxbenjaminfox/mutare_phoenix/tree/HEAD/examples/demo) is
a standalone mini-project — an auth plug and a few controller actions over a tiny
`Plug.Conn` / `Phoenix.Controller` stand-in — with deliberate test gaps that surface
survivors in the halt and status families (from `mutare_plug`) and the redirect, body, and
download families (this package). From the repo root:

```
mix compile
mix mutare examples/demo
```

## Scope

The `Plug.Conn` families live in the base
[`mutare_plug`](https://hex.pm/packages/mutare_plug); LiveView is the companion
`mutare_phoenix_live_view`, which builds on this package. Compose `Mutare.Plug.all/0`
alongside `Mutare.Phoenix.all/0` (see "Usage") for the full conn + controller surface.

## License

MIT — see [LICENSE](LICENSE).
