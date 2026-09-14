# Demo: Phoenix requests, messages, and tokens

A standalone mini-project with an auth plug, controller actions, a room channel,
PubSub notifications, and invitation tokens. Small framework stand-ins keep it
dependency-free. The mutators recognise the same module names and channel behaviour
as in a real Phoenix app; only the application code in `lib/demo` is mutated.

Like the other Mutare packages' examples, this demo has a single, deliberately partial
test suite. Its survivors expose missing assertions; its kills show which behaviours
the tests already check. The walkthrough below explains how to close each gap.

## Running

From the repo root (compile the package once so both packages' mutators are loadable —
`mutare_plug`'s families come in through the dependency):

```sh
mix compile
mix mutare examples/demo
```

The run scans **25 mutants across five files**. The observed results are:

| Families | Killed | Survived |
| --- | --- | --- |
| Plug and controller families | 5 | 7 |
| `:channel_reply` | 1 | 2 |
| `:channel_message` | 0 | 3 |
| `:pubsub` | 0 | 3 |
| `:token` | 1 | 3 |
| **Total (28.0%)** | **7** | **18** |

```text
mutation score: 28.0%  (7 killed, 18 survived, 25 total)
```

To run just the tests, from `examples/demo`:

```sh
mix test                    # 18 tests, 0 failures
```

## Plug and controller gaps

The first two families come from `mutare_plug`; the rest belong to this package:

- **`:plug_halt` — the forgotten halt** (`Demo.Auth`). The auth plug sets `401` *and*
  halts. The test asserts the `401` (so the `:http_status` mutant `:unauthorized →
  :forbidden` is **killed**) but never asserts the pipeline *halted*. Drop the `halt` and
  an anonymous request still gets `401` set — yet now falls through to the guarded action.
  The missing `assert conn.halted` is the gap; the classic authorization-bypass mutation.

- **`:http_status` — the unasserted status** (`Demo.PageController.create`). `create`
  answers `201 Created`, but its test checks only the response *body* (`%{id: 1}`), never
  the status. So swapping `:created` for another success (`:ok`, `:accepted`) is invisible.
  Two survivors, one per plausible sibling. (Contrast `index`, which **does** assert
  `:ok` — its `:created`/`:no_content` mutants are killed.)

- **`:redirect_status` — the unasserted redirect status** (`Demo.PageController.login`).
  `login` redirects to `"/login"` with an explicit `:found`, but its test checks only the
  target. So changing the status to another valid redirect status (`:moved_permanently`,
  `:see_other`) is invisible. Two survivors, one per plausible sibling.

- **`:controller_body` — the unread body** (`Demo.PageController.ping`). `ping` answers
  `"pong"`, but its test asserts only that the body *is text* (`is_binary`), never what it
  says. So blanking it to `""` is invisible — the response was sent, and nothing checked
  its content. (Contrast `index` and `create`, which **do** assert their JSON bodies — their
  `%{}` mutants are killed.)

- **`:download_disposition` — the unasserted disposition** (`Demo.PageController.export`).
  `export` sends the report as an `:attachment` — the browser should *save* it — but its
  test checks only that the filename reached the `content-disposition` header. So flipping
  it to `:inline` (display in the browser instead) is invisible.

To close these five gaps, add the following assertions after the existing calls in their
respective tests:

| Test | Missing assertion |
| --- | --- |
| Anonymous request | `assert conn.halted` |
| Create | `assert conn.status == :created` |
| Login | `assert conn.status == :found` |
| Ping | `assert conn.resp_body == "pong"` |
| Export | `assert value == ~s(attachment; filename="report.csv")` |

## Channel replies and outbound messages

[`Demo.RoomChannel`](lib/demo/room_channel.ex) returns room metadata when joining,
echoes a ping, acknowledges leaving, broadcasts chat messages, pushes presence,
and sends a deferred receipt reply.

The [tests](test/demo/room_channel_test.exs) check only that joining succeeds,
leaving stops the channel, and outbound operations return `{:noreply, socket}`.
Dropping a join or stop reply preserves those success/stop tags; removing a
broadcast, push, or deferred reply preserves the callback return. All five mutations
survive. The ping test already checks its reply, so its `:channel_reply` mutant is killed.

Checking the exact join and stop reply tuples closes the two callback gaps:

```elixir
assert RoomChannel.join("room:lobby", %{}, socket) ==
         {:ok, %{room_id: "lobby"}, socket}

assert RoomChannel.handle_in("leave", %{}, socket) ==
         {:stop, :normal, {:ok, %{left: true}}, socket}
```

Checking delivery closes the three outbound-message gaps. Add these calls and assertions
to tests using the existing socket setup:

```elixir
RoomChannel.handle_in("message", %{body: "hello"}, socket)
assert_receive {:broadcast, "room:lobby", "message", %{body: "hello"}}

RoomChannel.handle_in("presence", %{}, socket)
assert_receive {:push, "presence", %{online: 1}}

ref = make_ref()
RoomChannel.handle_info({:receipt_ready, {self(), ref}, 7}, socket)
assert_receive {:reply, ^ref, {:ok, %{receipt_id: 7}}}
```

Replacing an outbound call with `:ok` now fails the corresponding receive assertion.

## PubSub subscriptions and delivery

[`Demo.Notifications`](lib/demo/notifications.ex) watches report updates, stops
watching them, and publishes an update. The [tests](test/demo/notifications_test.exs)
check only `:ok`, which is also what the removal mutants return.

To close these gaps, exercise each effect independently:

- After `watch/2`, broadcast a fixture message and assert it arrives.
- After `unwatch/2`, broadcast a fixture message and assert it does not arrive.
- Before `published/2`, subscribe the test process and assert the update arrives.

For example, the unsubscription test can check that delivery stops:

```elixir
Phoenix.PubSub.subscribe(Demo.PubSub, "report:7")
Notifications.unwatch(Demo.PubSub, 7)
Phoenix.PubSub.broadcast(Demo.PubSub, "report:7", {:published, 7})
refute_receive {:published, 7}, 0
```

Use `Phoenix.PubSub` directly for fixture setup and broadcasts so each added test
isolates one application operation. Test code is outside the mutation target. The
existing setup starts a supervised Registry that is stopped after each test, so
subscriptions cannot leak between tests. The stand-in sends synchronously, allowing
the unsubscription test to inspect the mailbox immediately without a timing guess.

## Token scheme, payload, and expiry

[`Demo.Invites`](lib/demo/invites.ex) signs a user id and accepts invitations for one
hour. The [tests](test/demo/invites_test.exs) check that issuing returns a
binary and that the reader accepts an independently signed, fresh fixture. This
kills the reader's `verify` → `decrypt` mutation, but leaves three survivors:

- Issuing with `encrypt` still returns a binary; no test reads that issued token.
- Issuing with a `nil` payload still returns a binary; no test checks its user id.
- Changing `max_age: 3600` to `max_age: :infinity` still accepts the fresh fixture.

Round-trip an issued token and check its user id to kill both issuing mutations:

```elixir
token = Invites.issue(@context, 7)
assert Invites.accept(@context, token) == {:ok, 7}
```

Present an expired token to kill the expiry mutation:

```elixir
token = Phoenix.Token.sign(@context, "invite", 7,
  signed_at: System.system_time(:second) - 7200)
assert Invites.accept(@context, token) == {:error, :expired}
```

Backdating through the
[`signed_at:` option](https://hexdocs.pm/phoenix/Phoenix.Token.html#sign/4)
avoids sleeping or testing close to the expiry boundary.

## What the stand-ins model

`lib/phoenix_surface.ex` models conn transformations. `lib/messaging_surface.ex`
delivers BEAM messages and uses a duplicate-key Registry for local subscriptions;
it does not model WebSocket transport or distributed PubSub. In a real Phoenix
channel test, use the corresponding `Phoenix.ChannelTest` assertions.

`lib/token_surface.ex` encodes the scheme, context, salt, payload, and timestamp,
then checks them when reading. **It does not sign or encrypt anything** and must
never be used for authentication. Its role is to make scheme, payload, and expiry
mutations observable in this dependency-free demo.

> Why `:ok → :error` (or `:mutare`) doesn't already cover `:http_status`, `:redirect_status`,
> or `:download_disposition`: in those positions both of Mutare's built-in atom swaps
> **crash** (`:error`/`:mutare` aren't valid statuses, and Phoenix rejects any disposition
> but `:attachment`/`:inline`), an uninformative kill. These families swap to a *valid*
> sibling so a survivor means a genuine missing assertion, not a crash — and Mutare's overlap
> pruning drops the redundant crashing leaves. `:controller_body` earns its place the same
> way against the built-in string family: on a literal body its whole-call blank supersedes
> the `""`/`"mutare"` leaves, so one clean "is the body read?" mutant remains.
