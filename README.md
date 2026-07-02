# Mutare Phoenix

Custom [Mutare](https://hex.pm/packages/mutare) mutators for the **Phoenix request surface** —
the `Plug.Conn` / `Phoenix.Controller` calls a plug or controller action performs.

A plug or action returns a *transformed conn*, so its whole contract is **which
conn-transforming call ran** — the status it set, whether it halted.
These are exactly the calls a suite tends to under-assert: a test that checks "something
happened" but not *which* transformation leaves a gap. `mutare_phoenix` turns each such gap
into a located [Mutare](https://hex.pm/packages/mutare) survivor.

## The two families

`Mutare.Phoenix.all/0` returns two mutator families:

| Family | Name | Mutation | The gap a survivor exposes |
| --- | --- | --- | --- |
| `Mutare.Phoenix.Plug` | `:plug_halt` | removes `Plug.Conn.halt/1` | no test depends on this plug *halting* — the classic authorization-bypass |
| `Mutare.Phoenix.Response` | `:http_status` | swaps the atom status of `Plug.Conn.put_status/2`, `send_resp/3`, and `resp/3` for a same-family sibling (`:ok → :created`, `:unauthorized → :forbidden`) | no test pins the exact status |

Each family matches its call written directly (`Plug.Conn.halt(conn)`), aliased, or
bare-imported (`halt(conn)`, the form `use MyAppWeb, :controller` produces).

## Usage

`mutare_phoenix` rides on the [Mutare](https://hex.pm/packages/mutare) engine, so add both as
`:dev`/`:test` dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:mutare, "~> 0.1", only: [:dev, :test], runtime: false},
    {:mutare_phoenix, "~> 0.1", only: [:dev, :test], runtime: false}
  ]
end
```

Then list the families in `.mutare.exs`. Setting `:mutators` **replaces** Mutare's default
set, so include the `:builtins` family to keep the built-ins on:

```elixir
# .mutare.exs
[mutators: [:builtins] ++ Mutare.Phoenix.all()]
```

Run it the usual way:

```
mix mutare
```

## Configuring a family

`:http_status`'s swap table is tunable. Give the family `{module, opts}` with a `:swaps`
map — a status you list **replaces** its built-in siblings, an empty list **disables** it,
and any status you omit keeps its built-in siblings. Configuring a family means listing it
yourself, so expand `Mutare.Phoenix.all/0` into its members and replace that one entry:

```elixir
# .mutare.exs — narrow :ok to one sibling, stop mutating :no_content, add a teapot
[
  mutators: [
    :builtins,
    Mutare.Phoenix.Plug,
    {Mutare.Phoenix.Response, swaps: %{ok: [:created], no_content: [], im_a_teapot: [:bad_request]}}
  ]
]
```

Configured siblings must be valid `Plug.Conn.Status` reason atoms — trusted, not checked: a
sibling that isn't a real status produces a crashing mutant rather than the built-in table's
valid-but-wrong swap. See `Mutare.Phoenix.Response` for the full table.

## Why not the built-in atom mutators?

In a status position, Mutare's built-in atom swaps (`:ok → :error` / `:mutare`) produce a
value that **crashes** — an uninformative kill that tells you nothing about test quality.
`:http_status` swaps to a *valid* sibling, so a survivor means a genuine missing assertion
rather than a crash, and Mutare's overlap pruning drops the redundant crashing leaves at the
same range.

## Example

[`examples/demo`](https://github.com/foxbenjaminfox/mutare_phoenix/tree/master/examples/demo) is
a standalone mini-project — an auth plug and a few
controller actions over a tiny `Plug.Conn` / `Phoenix.Controller` stand-in — with deliberate
test gaps that surface a survivor in each family. From the repo root:

```
mix compile
mix mutare examples/demo
```

## Scope

LiveView is out of scope; it is handled by the companion `mutare_phoenix_live_view`.

## License

MIT — see [LICENSE](LICENSE).
