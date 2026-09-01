# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 - Unreleased

Initial release.

### Added

- `Mutare.Phoenix.Plug` (`:plug_halt`) — removes `Plug.Conn.halt/1`, pipe-aware
  (`halt(conn)` → `conn`; a piped stage → `Function.identity()`).
- `Mutare.Phoenix.Response` (`:http_status`) — swaps the atom status of
  `Plug.Conn.put_status/2`, `send_resp/3`, `resp/3`, `send_chunked/2`, and
  `send_file/3,4,5` for a curated same-family sibling; per-instance configurable
  via `{module, swaps: %{...}}`.
- `Mutare.Phoenix.Redirect` (`:redirect_status`) — swaps explicit atom
  `status:` options on `Phoenix.Controller.redirect/2` among valid redirect
  status siblings.
- `Mutare.Phoenix.Session` (`:plug_session`) — removes `Plug.Conn.put_session/3`,
  `delete_session/2`, and `clear_session/1`.
- `Mutare.Phoenix.Header` (`:resp_header`) — removes `Plug.Conn.put_resp_header/3`
  and `delete_resp_header/2`.
- `Mutare.Phoenix.Cookie` (`:resp_cookie`) — removes `Plug.Conn.put_resp_cookie/3,4`
  and `delete_resp_cookie/2,3`, plus flipping/dropping explicit string
  `same_site:` cookie policy options.
- Registers the `Phoenix.Router` DSL (`get`/`scope`/…) as `:skip` through
  `Mutare.MacroRouting`, so compile-time route definitions are left unmutated,
  and `Phoenix.Component.sigil_H/2` (`~H`) arguments as compile-time literals,
  so HEEx never poisons the metamutant build.
- `Mutare.Phoenix.all/0` for splicing all Phoenix families into a `:mutators`
  list.
