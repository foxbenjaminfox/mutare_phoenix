# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`mutare_phoenix` is an Elixir library of **custom [Mutare](https://hex.pm/packages/mutare) mutators** for the Phoenix controller surface — the `Phoenix.Controller` calls a controller action performs on the conn — plus the defensive `Mutare.MacroRouting` extension that keeps Phoenix's compile-time macros from poisoning the metamutant build. It does not test Phoenix apps directly; it plugs into the Mutare mutation-testing engine. See `README.md` for the user-facing description and `examples/demo/README.md` for a worked walkthrough.

## Commands

```sh
mix deps.get                       # fetch deps (mutare and mutare_plug are path deps at ../mutare, ../mutare_plug)
mix compile
mix test                           # full suite (async)
mix test test/mutare/phoenix/redirect_test.exs          # one file
mix test test/mutare/phoenix/redirect_test.exs:20       # one test by line
mix check                          # CI gate: format --check-formatted, credo, dialyzer
mix dialyzer                       # type analysis on its own (PLTs cached in priv/plts)
mix format                         # apply formatting
mix docs                           # ExDoc (dev only)
```

Run the demo target (dogfoods the package, composed with `mutare_plug`, against a project with deliberate test gaps):

```sh
mix compile                        # MUST compile the root first — the demo's .mutare.exs
mix mutare examples/demo           # appends the compiled packages' ebins to its code path
```

`mix check` is the canonical pre-commit gate (defined in `mix.exs` aliases): `format --check-formatted`, then `credo`, then `dialyzer`. It does **not** run the test suite — run `mix test` separately. The first `dialyzer` invocation builds PLTs (a few minutes) into `priv/plts/` (git-ignored); subsequent runs are fast.

## Dependencies & layout

- `{:mutare, path: "../mutare"}` and `{:mutare_plug, path: "../mutare_plug"}` are **path deps** for local dev — both must be present as sibling checkouts for anything to compile. The engine source (`Mutare.Mutator`, `Mutare.MacroRouting`, `Mutare.Extension`, `Mutare.Test`, `Mutare.Transform.Calls`, `Mutare.AST`, the `# mutare:ignore` reader, etc.) lives in `../mutare/lib` — **read it there when you need the exact contract** of a callback or helper, since this package only consumes Mutare's public extension points.
- This package **builds on** `mutare_plug` the way `phoenix` builds on `plug`: depending on it puts the `Plug.Conn` families (`Mutare.Plug.all/0`) on the code path, but `Mutare.Phoenix.all/0` returns **only this package's families** — a consumer composes the two presets explicitly. The engine does not dedup a family listed twice, which is why `all/0` must never fold `Mutare.Plug.all/0` in.
- `lib/mutare/phoenix.ex` is the public entry (`all/0`) **and** the `:extensions` routing entry (`macro_routes/0`); each family is one module under `lib/mutare/phoenix/`. Test files mirror that layout under `test/mutare/phoenix/`.
- `mutare_phoenix_live_view` builds on this package in turn; keep families belonging to the LiveView socket surface out of here (see Scope).

## Architecture

### Name-based matching, zero Phoenix/Plug dependency

The package depends on **neither `phoenix` nor `plug`**. Mutators pattern-match module *names* as AST atoms (`[:Phoenix, :Controller]`, `Phoenix.Router`, `Phoenix.Component`) — alias/import resolution happens in the *target* project where those libs are present. This is the single most important constraint: never add a runtime call into `Phoenix.Controller`, `Plug.Conn`, or `Plug.Conn.Status`.

### The families (each a `Mutare.Mutator`)

Registered in `lib/mutare/phoenix.ex` via `@families` / `all/0`:

- `Mutare.Phoenix.Redirect` — `:redirect_status`, swaps explicit redirect `status:` atoms of `Phoenix.Controller.redirect/2` for a redirect-status sibling (curated `@status_swaps` table).
- `Mutare.Phoenix.Body` — `:controller_body`, blanks the body of `json/2` (to `%{}`), `text/2`, and `html/2` (to `""`); its single-argument rewrite is an Overlap-covering mutation, so the built-in `:string` leaves on a literal text/html body are pruned automatically. `render/3` is deliberately out of scope (its argument is a template name, not a body).
- `Mutare.Phoenix.Download` — `:download_disposition`, flips an explicit `disposition:` atom of `send_download/3` between `:attachment` and `:inline` (the only two Phoenix accepts; anything else raises, so the built-in `:atom` leaf there is a crash and gets pruned).

`Mutare.Phoenix.Options` (`@moduledoc false`) is the shared keyword-options plumbing for the option families (`Redirect`, `Download`): `keyword_list/1` reads the pairs out of either written shape (bare trailing keywords or an explicit bracketed list) with a `rewrap` closure that restores the shape, `atom_literal/1` reads a literal atom value, and `swap_literal/2` swaps a value in place under the clean-meta rule.

To add a family: implement the `Mutare.Mutator` behaviour, add the module to `@families` (and the `all/0` doctest, which asserts the exact list), export any newly matched function/arity from `test/support/phoenix_stubs.ex`, and add a test module mirroring the existing ones. `Plug.Conn` calls never belong here — those are `mutare_plug`. Flash atoms (`put_flash/3`'s `:info` / `:error`) are deliberately **not** a family: the built-in atom families already flip them (`:info → :mutare`, `:error → :ok`), so a test that never checks the flash kind is caught regardless.

### The `:extensions` entry — `Mutare.Phoenix.macro_routes/0`

`Mutare.Phoenix` implements `Mutare.MacroRouting` (and is **not** a mutator — it has no `name/0`; `Mutare.Extension` rejects mutator modules under `:extensions`, and `phoenix_test.exs` pins this). Its `macro_routes/0` registers as `:skip`:

- the `Phoenix.Router` DSL (`get`/`scope`/`pipeline`/…, any arity) — a router body is compile-time code that runs once as mutant 0 under Mutare's compile-once model, so a mutation there could never activate; skipping saves mutant ids;
- `Phoenix.Component.sigil_H/2` — HEEx sigil arguments must stay compile-time literals. Left unregistered, Mutare's imported-call witness would splice an unreachable `sigil_H(arg1, arg2)`; macros still expand in unreachable code, so Phoenix raises before poison recovery can isolate a single mutant. Mutations *around* the `~H` expression (e.g. `:return_value`) remain available.

A routing-only module belongs under `:extensions`, not `:mutators` (`Mutare.Mutator.Dispatch.implemented_by?/1` requires `name/0` plus a producer). This mirrors `mutare_phoenix_swoosh`, whose front module is likewise its `:extensions` entry.

### Mutare extension points used

- `Mutare.Calls.resolved_call(node)` → `{module_path, fun, args, rebuild}` — resolves direct/aliased/bare-imported call forms uniformly (the published facade; `Mutare.Transform.Calls` is core-internal). The `rebuild` closure reconstructs the call from new args.
- `Mutare.Mutator` callbacks: `name/0` plus at least one producer — `mutate/1` and/or the context-aware `mutate/2`, both optional individually. `Mutare.MacroRouting`'s `macro_routes/0` lives on the front module.
- `Mutare.AST` — `parse!`, `literal`, `literal_value` for AST construction/inspection.
- `Mutare.Mutator.effective_arity/2` and `visible_index/2` — recover argument positions under pipe context.

### `mutate/1` vs `mutate/2` (pipe awareness)

`mutate/2` receives `%{pipe_mode: ...}` context; `mutate/1` is node-local with no pipe context. Both are optional (a family needs at least one producer), so implement exactly the one that fits how the swappable position behaves. Every family implements only `mutate/2`: the swapped position (an options list, a body) is a non-first effective argument whose visible index depends on pipe context, so a node-local `mutate/1` could never fire and is omitted.

### Recurring AST conventions (apply to any new family)

- **Clean-meta rule:** to change a *value* in place, keep the original node's Sourceror metadata (so it re-renders inline); only use fresh meta for genuinely new nodes. Carrying stale line metadata makes Sourceror expand calls across lines. See `Options.swap_literal/2` and `Body.blank_body/2`.
- **Valid-but-wrong swaps + Overlap pruning:** families swap to *valid* siblings (not crashing values). Because a single-argument rewrite touches the exact same AST node as Mutare's built-in leaf mutators (the `:atom` family's `:mutare` under `:redirect_status` and `:download_disposition`, the `:string` `""`/`"mutare"` under `:controller_body`), `Mutare.Transform.Overlap` auto-prunes the redundant leaves — no declaration needed. Tests assert this (the "superseding" describe blocks). The rewrite must substitute exactly one node and keep the call form otherwise identical (bare imported calls stay bare); a requalified or multi-node change loses the covering footprint and the leaves resurface.
- **Consumer-side silencing:** a deliberate site in a host project is silenced with a family-scoped `# mutare:ignore[<family>]` comment (e.g. `# mutare:ignore[redirect_status]`) — an engine feature (`Mutare.Ignore`), not something this package implements.

## Tests

Test files mirror `lib/` under `test/mutare/phoenix/`; `test/mutare/phoenix_test.exs` covers `all/0`, the `:extensions` routing, and a cross-package integration check over `Mutare.Plug.all() ++ Mutare.Phoenix.all()`. They use the `Mutare.Test` helpers (imported in each test module):

- `diffs_for(source, mutators, name[, opts])` → `[{original_src, mutated_src}, ...]` filtered to one family name; pass `extensions: [Mutare.Phoenix]` in `opts` to enable the routing.
- `diffs(source, mutators[, opts])` → `[{name, ...}, ...]` across families.
- `node_mutations(src, module[, pipe_mode])` → mutated source strings for the pure-AST node path.
- `metamutant_source(source, mutators[, opts])` / `assert_metamutant_compiles(source, mutators[, opts])` — the critical safety check that every generated mutant still compiles.

`test/support/phoenix_stubs.ex` defines minimal `Plug.Conn` / `Phoenix.Controller` / `Phoenix.Router` / `Phoenix.Component` stand-ins, loaded **only in `:test`** (via `elixirc_paths(:test)` in `mix.exs`). They exist so bare-imported calls resolve (import resolution reflects on exported arities, so the module must be loadable) and so generated metamutants compile without "undefined function" warnings — they carry no behaviour worth testing. The `Plug.Conn` slice is only what the integration test reaches for; `mutare_plug` carries the full stand-in (a dep's `test/support` is never compiled into this build, so the two never collide).

## Scope — what lives elsewhere

This package owns only the **`Phoenix.Controller`** surface and Phoenix's macro routing. Adjacent concerns are deliberately handled by other packages, and keeping the split clean matters (overlapping mutators double-fire on the same range):

- **The `Plug.Conn` surface** (`halt`, `put_status`/`send_resp`/… statuses, session, headers, cookies, body) is the base `mutare_plug`. Conn-level and controller-level calls resolve to different modules, so the split is clean.
- **The LiveView socket surface** (navigation, reply tuples, streams, pushed events, `send_update`) is the companion `mutare_phoenix_live_view`. Conn-level redirects (`Phoenix.Controller.redirect/2`) and socket-level ones (`Phoenix.LiveView.redirect/2`) resolve to different modules.
- **Integer statuses** (`status: 302`) are left to Mutare's built-in literal family; `:redirect_status` only swaps *atom* statuses. Likewise the option families mutate only an *explicit* literal option — a call relying on Phoenix's default is left alone (the package does not add options that were not written).
- **Flash kinds** (`put_flash/3`) are covered by the built-in atom families (`:info → :mutare`, `:error → :ok`) and deliberately not duplicated here.
- **Crashing atom swaps** in status positions are left to the built-in `:atom`/`:convention` families and then pruned by Overlap, so this package never emits a knowingly-crashing mutant.
