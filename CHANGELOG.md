# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.1.0

Initial release.

- `Mutare.Phoenix.Plug` (`:plug_halt`) — removes `Plug.Conn.halt/1`, pipe-aware
  (`halt(conn)` → `conn`; a piped stage → `Function.identity()`).
- `Mutare.Phoenix.Response` (`:http_status`) — swaps the atom status of
  `Plug.Conn.put_status/2`, `send_resp/3`, and `resp/3` for a curated same-family
  sibling; per-instance configurable via `{module, swaps: %{...}}`.
- Registers the `Phoenix.Router` DSL (`get`/`scope`/…) as `:skip` through
  `Mutare.MacroRouting`, so compile-time route definitions are left unmutated.
- `Mutare.Phoenix.all/0` for splicing both families into a `:mutators` list.
