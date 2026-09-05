# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 - Unreleased

Initial release. Builds on `mutare_plug`, which carries the `Plug.Conn`
families (`:plug_halt`, `:http_status`, `:plug_session`, `:resp_header`,
`:resp_cookie`, `:resp_body`).

### Added

- `Mutare.Phoenix.Redirect` (`:redirect_status`) — swaps explicit atom
  `status:` options on `Phoenix.Controller.redirect/2` among valid redirect
  status siblings.
- `Mutare.Phoenix` as a `Mutare.MacroRouting` extension (list it under
  `:extensions`): registers the `Phoenix.Router` DSL (`get`/`scope`/…) as
  `:skip`, so compile-time route definitions are left unmutated, and
  `Phoenix.Component.sigil_H/2` (`~H`) arguments as compile-time literals, so
  HEEx never poisons the metamutant build.
- `Mutare.Phoenix.all/0` for splicing the Phoenix families into a `:mutators`
  list, composing with `Mutare.Plug.all/0`.
