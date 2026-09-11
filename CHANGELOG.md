# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

The package now covers the Phoenix server-side surface beyond controllers:
channel callback replies, channel outbound messages, PubSub, and tokens.

### Added

- `Mutare.Phoenix.ChannelReply` (`:channel_reply`) — drops the reply element
  of a `Phoenix.Channel` callback return (`{:ok, reply, socket}` →
  `{:ok, socket}`, `{:reply, reply, socket}` → `{:noreply, socket}`,
  `{:stop, reason, reply, socket}` → `{:stop, reason, socket}`), gated on
  `@behaviour Phoenix.Channel` ("does any test check the reply?").
- `Mutare.Phoenix.ChannelMessage` (`:channel_message`) — removes a
  `Phoenix.Channel` outbound message (`broadcast/3` and its `!`/`_from`
  siblings, `push/3`, `reply/2`), collapsing the call to `:ok`; variant labels
  `broadcast`, `push`, `reply`.
- `Mutare.Phoenix.PubSub` (`:pubsub`) — removes a `Phoenix.PubSub` `subscribe`,
  `unsubscribe`, or broadcast call (every `broadcast`/`broadcast_from`/
  `local_broadcast`/`direct_broadcast` form), collapsing it to `:ok`; variant
  labels `subscribe`, `unsubscribe`, `broadcast`.
- `Mutare.Phoenix.Token` (`:token`) — swaps a `Phoenix.Token` call for its
  sibling scheme (`sign` ↔ `encrypt`, `verify` ↔ `decrypt`; variant `scheme`),
  blanks a `sign`/`encrypt` payload to `nil` (`payload`), and turns an explicit
  integer `max_age:` of `verify`/`decrypt` into `:infinity` (`expiry`). The
  `max_age:` position is marked with the shared `:timeout` label, so the
  built-in integer/atom families leave the duration literal alone.

### Changed

- `Mutare.Phoenix.all/0` now returns seven families: the four above appended
  after the controller ones.

## [0.1.0] - 2026-09-07

Initial release. Builds on `mutare_plug`, which carries the `Plug.Conn`
families (`:plug_halt`, `:http_status`, `:plug_session`, `:resp_header`,
`:resp_cookie`, `:resp_body`).

### Added

- `Mutare.Phoenix.Redirect` (`:redirect_status`) — swaps explicit atom
  `status:` options on `Phoenix.Controller.redirect/2` among valid redirect
  status siblings.
- `Mutare.Phoenix.Body` (`:controller_body`) — blanks the body argument of
  `Phoenix.Controller.json/2` to `%{}` and of `text/2` / `html/2` to `""`
  ("does any test read the rendered body?"); on a literal text/html body its
  whole-call rewrite supersedes the built-in string family's sentinel leaves
  via Mutare's overlap pruning.
- `Mutare.Phoenix.Download` (`:download_disposition`) — flips the explicit
  `disposition:` option of `Phoenix.Controller.send_download/3` between
  `:attachment` and `:inline`.
- `Mutare.Phoenix` as a `Mutare.CallRouting` extension (list it under
  `:extensions`): routes the `Phoenix.Router` DSL (`get`/`scope`/…) `:skip`,
  so compile-time route definitions are left unmutated, and
  `Phoenix.Component.sigil_H/2` (`~H`) arguments as compile-time literals, so
  HEEx never poisons the metamutant build.
- `Mutare.Phoenix.all/0` for splicing the Phoenix families into a `:mutators`
  list, composing with `Mutare.Plug.all/0`.

[Unreleased]: https://github.com/foxbenjaminfox/mutare_phoenix/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/foxbenjaminfox/mutare_phoenix/releases/tag/v0.1.0
