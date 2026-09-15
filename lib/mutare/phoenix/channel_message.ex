defmodule Mutare.Phoenix.ChannelMessage do
  @moduledoc """
  `:channel_message` — removes a `Phoenix.Channel` outbound-message call, collapsing it to
  the `:ok` it returns on success. Three kinds, each a variant label:

      broadcast(socket, "new_msg", %{body: body})        ->  :ok     # broadcast
      broadcast!(socket, "new_msg", %{body: body})       ->  :ok     # broadcast
      broadcast_from(socket, "typing", %{})              ->  :ok     # broadcast
      broadcast_from!(socket, "typing", %{})             ->  :ok     # broadcast
      push(socket, "presence_state", state)              ->  :ok     # push
      reply(ref, {:ok, %{status: "done"}})               ->  :ok     # reply

  A `broadcast` survivor means no test asserts the message reached the topic's subscribers
  (`Phoenix.ChannelTest.assert_broadcast/3`); a `push` survivor, that nothing asserts the
  client received the event (`assert_push/3`); a `reply` survivor, that nothing asserts the
  deferred reply arrived (`assert_reply/4`). Suppress one kind with
  `# mutare:ignore[channel_message:push]`, or the whole family with
  `# mutare:ignore[channel_message]`.

  The `:channel_reply` family mutates *inline* replies — the `{:reply, reply, socket}`
  tuples returned by `handle_in/3`; this family mutates only outbound-message calls.
  Mutare's built-in `:convention` family mutates the `:ok` / `:error` status inside a
  reply payload, and `:string` mutates the event string. Enable them alongside this
  family to mutate each part independently.

  Only the defined arities match — `broadcast/3` and its three siblings, `push/3`, `reply/2` —
  so a name-matched call of any other arity (reachable only by an explicit qualifier) is left
  alone, keeping every metamutant compiling. A piped call is left alone too: none of these
  returns the socket, so there is no faithful pass-through to substitute, and piping into
  them is never idiomatic. Matches direct (`Phoenix.Channel.broadcast(...)`), aliased, and
  bare-imported (`use Phoenix.Channel`-injected) calls.
  """
  @behaviour Mutare.Mutator

  alias Mutare.Mutator.Mutation
  alias Mutare.Phoenix.Removal

  # The outbound calls, each with its one real arity and the kind it is reported under.
  @table %{
    broadcast: {[3], "broadcast"},
    broadcast!: {[3], "broadcast"},
    broadcast_from: {[3], "broadcast"},
    broadcast_from!: {[3], "broadcast"},
    push: {[3], "push"},
    reply: {[2], "reply"}
  }

  @impl Mutare.Mutator
  @spec name() :: :channel_message
  def name, do: :channel_message

  # Variant vocabulary for `# mutare:ignore[channel_message:<kind>]`, tagged at production.
  @impl Mutare.Mutator
  @spec variants() :: [String.t()]
  def variants, do: ~w(broadcast push reply)

  # No `mutate/1`: the piped form is deliberately skipped, which needs the pipe context only
  # `mutate/2` carries.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutation.t()]
  def mutate(node, %{pipe_mode: pipe_mode}),
    do: Removal.removed(node, Phoenix.Channel, @table, pipe_mode)
end
