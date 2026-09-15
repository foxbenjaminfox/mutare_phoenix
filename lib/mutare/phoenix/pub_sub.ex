defmodule Mutare.Phoenix.PubSub do
  @moduledoc """
  `:pubsub` — removes a `Phoenix.PubSub` call, collapsing it to the `:ok` it returns on
  success. Three kinds, each a variant label:

      Phoenix.PubSub.subscribe(MyApp.PubSub, "room:" <> id)         ->  :ok   # subscribe
      Phoenix.PubSub.unsubscribe(MyApp.PubSub, "room:" <> id)       ->  :ok   # unsubscribe
      Phoenix.PubSub.broadcast(MyApp.PubSub, topic, {:new, msg})    ->  :ok   # broadcast
      Phoenix.PubSub.broadcast_from!(MyApp.PubSub, self(), t, msg)  ->  :ok   # broadcast

  A `subscribe` survivor means no test delivers a message on that topic and checks the
  process handled it — the LiveView that subscribes in `mount/3` and re-renders on
  `handle_info/2`, say, with no test ever broadcasting to it. A `broadcast` survivor means no
  test asserts the message reached a subscriber (a test process that subscribed and
  `assert_receive`s, or a LiveView whose render is checked after the broadcast). An
  `unsubscribe` survivor means no test depends on the messages *stopping*. Suppress one kind
  with `# mutare:ignore[pubsub:subscribe]`, or the whole family with `# mutare:ignore[pubsub]`.

  The `broadcast` kind covers the whole broadcast surface: `broadcast/3,4`, `broadcast!/3,4`,
  `broadcast_from/4,5`, `broadcast_from!/4,5`, `local_broadcast/3,4`,
  `local_broadcast_from/4,5`, `direct_broadcast/4,5`, and `direct_broadcast!/4,5`. The
  channel-level `Phoenix.Channel.broadcast/3` call resolves to a different module and is
  covered by `:channel_message`.

  Only the defined arities match, so a name-matched call of any other arity (reachable only by an
  explicit qualifier) is left alone, keeping every metamutant compiling. A piped call is left
  alone too: none of these returns its first argument, so there is no faithful pass-through
  to substitute, and piping a pubsub name into them is never idiomatic. Matches direct
  (`Phoenix.PubSub.subscribe(...)`), aliased, and bare-imported calls.
  """
  @behaviour Mutare.Mutator

  alias Mutare.Mutator.Mutation
  alias Mutare.Phoenix.Removal

  # Every `Phoenix.PubSub` call that sends or routes a message, with its real arities (the
  # trailing optional argument is the dispatcher, or `subscribe`'s options) and the kind it is
  # reported under.
  @table %{
    subscribe: {[2, 3], "subscribe"},
    unsubscribe: {[2], "unsubscribe"},
    broadcast: {[3, 4], "broadcast"},
    broadcast!: {[3, 4], "broadcast"},
    broadcast_from: {[4, 5], "broadcast"},
    broadcast_from!: {[4, 5], "broadcast"},
    local_broadcast: {[3, 4], "broadcast"},
    local_broadcast_from: {[4, 5], "broadcast"},
    direct_broadcast: {[4, 5], "broadcast"},
    direct_broadcast!: {[4, 5], "broadcast"}
  }

  @impl Mutare.Mutator
  @spec name() :: :pubsub
  def name, do: :pubsub

  # Variant vocabulary for `# mutare:ignore[pubsub:<kind>]`, tagged at production.
  @impl Mutare.Mutator
  @spec variants() :: [String.t()]
  def variants, do: ~w(subscribe unsubscribe broadcast)

  # No `mutate/1`: the piped form is deliberately skipped, which needs the pipe context only
  # `mutate/2` carries.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutation.t()]
  def mutate(node, %{pipe_mode: pipe_mode}),
    do: Removal.removed(node, Phoenix.PubSub, @table, pipe_mode)
end
