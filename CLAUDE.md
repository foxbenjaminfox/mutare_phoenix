# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`mutare_phoenix` is an Elixir library of **custom [Mutare](https://hex.pm/packages/mutare) mutators** for the Phoenix request surface — the `Plug.Conn` / `Phoenix.Controller` calls a plug or controller action performs. It does not test Phoenix apps directly; it plugs into the Mutare mutation-testing engine and adds focused mutator families that turn under-asserted conn transforms into located survivors. See `README.md` for the user-facing description of the families and `examples/demo/README.md` for a worked walkthrough.

## Commands

```sh
mix deps.get                       # fetch deps (mutare is a path dep at ../mutare)
mix compile
mix test                           # full suite (async)
mix test test/mutare/phoenix/response_test.exs          # one file
mix test test/mutare/phoenix/response_test.exs:120      # one test by line
mix check                          # CI gate: format --check-formatted, credo, dialyzer
mix dialyzer                       # type analysis on its own (PLTs cached in priv/plts)
mix format                         # apply formatting
mix docs                           # ExDoc (dev only)
```

Run the demo target (dogfoods the package against a project with deliberate test gaps):

```sh
mix compile                        # MUST compile the root first — the demo's .mutare.exs
mix mutare examples/demo           # appends the compiled package's ebins to its code path
```

`mix check` is the canonical pre-commit gate (defined in `mix.exs` aliases): `format --check-formatted`, then `credo`, then `dialyzer`. It does **not** run the test suite — run `mix test` separately. The first `dialyzer` invocation builds PLTs (a few minutes) into `priv/plts/` (git-ignored); subsequent runs are fast.

## Dependencies & layout

- `{:mutare, path: "../mutare"}` is a **path dep** for local dev — the engine must be present as a sibling checkout for anything to compile. The engine source (`Mutare.Mutator`, `Mutare.Test`, `Mutare.Transform.Calls`, `Mutare.AST`, the `# mutare:ignore` reader, etc.) lives in `../mutare/lib` — **read it there when you need the exact contract** of a callback or helper, since this package only consumes Mutare's public extension points.
- `lib/mutare/phoenix.ex` is the public entry (`all/0`); each family is one module under `lib/mutare/phoenix/`. Test files mirror that layout under `test/mutare/phoenix/`.
- This is the **base** package of the family. `mutare_phoenix_live_view` builds on it (the way `phoenix_live_view` builds on `phoenix`); keep families belonging to the LiveView socket surface out of here (see Scope).

## Architecture

### Name-based matching, zero Phoenix/Plug dependency

The package depends on **neither `phoenix` nor `plug`**. Mutators pattern-match module *names* as AST atoms (`[:Plug, :Conn]`, `[:Phoenix, :Controller]`, `Phoenix.Router`) — alias/import resolution happens in the *target* project where those libs are present. This is the single most important constraint: never add a runtime call into `Plug.Conn`, `Phoenix.Controller`, or `Plug.Conn.Status`. For example, configured `:http_status` siblings are *trusted* to be valid statuses rather than validated, precisely to avoid reaching into the target project's `Plug.Conn.Status`.

### The families (each a `Mutare.Mutator`)

Registered in `lib/mutare/phoenix.ex` via `@families` / `all/0`:

- `Mutare.Phoenix.Plug` — `:plug_halt`, removes `Plug.Conn.halt/1`.
- `Mutare.Phoenix.Response` — `:http_status`, swaps an atom status of `put_status/2`, `send_resp/3`, `resp/3`, `send_chunked/2`, and `send_file/3,4,5` for a same-family sibling (curated `@status_swaps` table, per-instance configurable via `{module, swaps: %{...}}`).
- `Mutare.Phoenix.Redirect` — `:redirect_status`, swaps explicit redirect `status:` atoms.
- `Mutare.Phoenix.Session` — `:plug_session`, removes `put_session/3`, `delete_session/2`, `clear_session/1`, and `configure_session/2` (the session-fixation bypass).
- `Mutare.Phoenix.Header` — `:resp_header`, removes `put_resp_header/3`, `delete_resp_header/2`, and `put_resp_content_type/2,3`.
- `Mutare.Phoenix.Cookie` — `:resp_cookie`, removes `put_resp_cookie/3,4` and `delete_resp_cookie/2,3`, flips/drops explicit string `same_site:` options, and drops `max_age:` on `put_resp_cookie/4` (persistent → session cookie; a presence mutation the built-in integer family can't mint).
- `Mutare.Phoenix.Body` — `:resp_body`, blanks the body of `send_resp/3` and `resp/3` to `""`; its single-argument rewrite is an Overlap-covering mutation, so the built-in `:string` leaves on a literal body are pruned automatically.

To add a family: implement the `Mutare.Mutator` behaviour, add the module to `@families`, and add a test module mirroring the existing ones.

### Mutare extension points used

- `Mutare.Calls.resolved_call(node)` → `{module_path, fun, args, rebuild}` — resolves direct/aliased/bare-imported call forms uniformly (the published facade; `Mutare.Transform.Calls` is core-internal). The `rebuild` closure reconstructs the call from new args. This is the entry point in every family's `mutate`.
- `Mutare.Mutator` callbacks: `name/0` plus at least one producer — `mutate/1` and/or the context-aware `mutate/2`, both optional individually. Macro-argument routing lives on the separate `Mutare.MacroRouting` behaviour (`macro_routes/0`), which a mutator may also implement — listing it under `:mutators` auto-registers its routes.
- `Mutare.AST` — `parse!`, `literal`, `key_atom` for AST construction/inspection.
- `Mutare.Mutator.effective_arity/2` and `visible_index/2` — recover argument positions under pipe context.

### `mutate/1` vs `mutate/2` (pipe awareness)

`mutate/2` receives `%{pipe_mode: ...}` context; `mutate/1` is node-local with no pipe context. Both are optional (a family needs at least one producer), so implement exactly the one that fits how the swappable position behaves:

- Current conn-transform families implement only `mutate/2` — removal shape / status or option index depends on pipe context, so a node-local `mutate/1` could never fire and is simply omitted.
- A node-local family whose swappable position is pipe-independent (e.g. a fixed last argument) would implement only `mutate/1` instead.

### Recurring AST conventions (apply to any new family)

- **Clean-meta rule:** to change a *value* in place, keep the original node's Sourceror metadata (so it re-renders inline); only use fresh meta (e.g. `[format: :keyword]`) for genuinely new nodes. Carrying stale line metadata makes Sourceror expand calls across lines. See `swap_status/2`.
- **Valid-but-wrong swaps + Overlap pruning:** families swap to *valid* siblings (not crashing values). Because a single-argument rewrite touches the exact same AST node as Mutare's built-in leaf mutators — the atom families' `:mutare`/`:error` under `:http_status`, the `:string` `""`/`"mutare"` under `:resp_body` — `Mutare.Transform.Overlap` auto-prunes the redundant leaves — no declaration needed. Tests assert this (the "superseding" describe blocks). The rewrite must substitute exactly one node and keep the call form otherwise identical (bare imported calls stay bare); a requalified or multi-node change loses the covering footprint and the leaves resurface.
- **`macro_routes/0` `:skip` registration:** `Response` implements `Mutare.MacroRouting` and its `macro_routes/0` registers the `Phoenix.Router` DSL (`get`/`scope`/…) as `:skip` so Mutare leaves compile-time route definitions unmutated.
- **Consumer-side silencing:** a deliberate site in a host project is silenced with a family-scoped `# mutare:ignore[<family>]` comment (e.g. `# mutare:ignore[http_status]`) — an engine feature (`Mutare.Ignore`), not something this package implements, but the family names this package records (`:plug_halt`, `:http_status`, `:plug_session`, etc.) are what users put in the brackets.

## Tests

Test files mirror `lib/` under `test/mutare/phoenix/`. They use the `Mutare.Test` helpers (imported in each test module):

- `diffs_for(source, mutators, name)` → `[{original_src, mutated_src}, ...]` filtered to one family name.
- `diffs(source, mutators)` → `[{name, ...}, ...]` across families.
- `node_mutations(src, module[, pipe_mode])` → mutated source strings for the pure-AST node path.
- `assert_metamutant_compiles(source, mutators)` — the critical safety check that every generated mutant still compiles.

`test/support/phoenix_stubs.ex` defines minimal `Plug.Conn` / `Phoenix.Controller` / `Phoenix.Router` stand-ins, loaded **only in `:test`** (via `elixirc_paths(:test)` in `mix.exs`). They exist so bare-imported calls resolve (import resolution reflects on exported arities, so the module must be loadable) and so generated metamutants compile without "undefined function" warnings — they carry no behaviour worth testing.

## Scope — what lives elsewhere

This package owns only the **conn-level** request surface. Adjacent concerns are deliberately handled by other families, and keeping the split clean matters (overlapping mutators double-fire on the same range):

- **The LiveView socket surface** (navigation, reply tuples, streams, pushed events, `send_update`) is out of scope — it is the companion `mutare_phoenix_live_view`. Conn-level redirects (`Phoenix.Controller.redirect/2`) and socket-level ones (`Phoenix.LiveView.redirect/2`) resolve to different modules, so the split is clean.
- **Integer statuses** (`put_status(conn, 200)`) are left to Mutare's built-in literal family; `:http_status` only swaps *atom* statuses.
- **Crashing atom swaps** in status positions are left to the built-in `:atom`/`:convention` families and then pruned by Overlap, so this package never emits a knowingly-crashing mutant.
