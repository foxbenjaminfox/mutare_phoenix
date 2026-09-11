defmodule Mutare.Phoenix.ChannelReply do
  @moduledoc """
  `:channel_reply` — drops the reply element of a `Phoenix.Channel` callback's return tuple,
  reshaping it into a different but still valid return. Fires in modules that implement
  `@behaviour Phoenix.Channel` (which `use Phoenix.Channel` injects):

      join/3        {:ok, reply, socket}          ->  {:ok, socket}
      handle_in/3   {:reply, reply, socket}       ->  {:noreply, socket}
      handle_in/3   {:stop, reason, reply, socket} ->  {:stop, reason, socket}

  A survivor means no test checks the dropped reply: the join payload (`{:ok, reply, socket}
  = subscribe_and_join(...)` matched as `{:ok, _, socket}`), or a `handle_in` reply the test
  never `assert_reply`s. The returns that carry no reply — `{:noreply, socket}`,
  `{:ok, socket}`, `{:stop, reason, socket}`, `{:noreply, socket, timeout}` — have nothing to
  drop and are left alone. Silence a site with `# mutare:ignore[channel_reply]`.

  Recognised by tuple shape, independent of which function it sits in — like Mutare's
  built-in `:genserver` family and `mutare_phoenix_live_view`'s `:lv_reply`, whose
  `{:reply, payload, socket}` reshape this mirrors for the channel behaviour. A private helper
  in the channel module that returns a same-shaped `{:ok, value, socket}` is reshaped too;
  silence such a site with the ignore comment. The reply's `:ok` / `:error` status is
  Mutare's built-in `:convention` family, a different axis; the deferred `reply/2` call is
  `:channel_message`.

  Under `--no-expand-uses` the `@behaviour` that `use Phoenix.Channel` injects is invisible,
  so `:channel_reply` no-ops; a direct `@behaviour Phoenix.Channel` still works.
  """
  @behaviour Mutare.Mutator
  @behaviour Mutare.Mutator.Structural

  alias Mutare.AST

  @impl Mutare.Mutator
  @spec name() :: :channel_reply
  def name, do: :channel_reply

  # Every decision needs the enclosing module's behaviours, so this family produces only
  # through the behaviour-aware structural return hook — never node-locally.
  @impl Mutare.Mutator.Structural
  @spec return_replacements(Macro.t(), Mutare.Mutator.Structural.context()) :: [Macro.t()]
  def return_replacements(tail, %{behaviours: behaviours}) do
    if MapSet.member?(behaviours, Phoenix.Channel), do: reshaped(tail), else: []
  end

  # A 3- or 4-element tuple carries its own metadata (`{:{}, meta, [tag | rest]}`), and the
  # engine hands the return tail over directly — Sourceror only block-wraps bare literals, and
  # the returns analyzer already descends to a block's last statement — so there is no
  # wrapper to peel. A 2-tuple has no reply to drop.
  @spec reshaped(Macro.t()) :: [Macro.t()]
  defp reshaped({:{}, _meta, [tag | rest]}) when is_list(rest),
    do: returns_for(tag_name(tag), rest)

  defp reshaped(_tail), do: []

  # Drop the reply, keeping a valid channel return. The element layout is the callback
  # contract: `:ok`-3 and `:reply`-3 carry the reply second, `:stop`-4 third after the reason.
  @spec returns_for(atom() | nil, [Macro.t()]) :: [Macro.t()]
  defp returns_for(:ok, [_reply, socket]), do: [retuple(:ok, [socket])]
  defp returns_for(:reply, [_reply, socket]), do: [retuple(:noreply, [socket])]
  defp returns_for(:stop, [reason, _reply, socket]), do: [retuple(:stop, [reason, socket])]
  defp returns_for(_tag, _elements), do: []

  # Build `{tag, ...values}` as a Sourceror tuple node. The explicit `{:{}, [], [...]}` form
  # renders a 2-element list as the literal 2-tuple `{tag, value}`.
  @spec retuple(atom(), [Macro.t()]) :: Macro.t()
  defp retuple(tag, values), do: {:{}, [], [AST.literal(tag) | values]}

  # The atom of a control tag. Sourceror always wraps a tuple element's atom literal in a
  # block, so the tag arrives as `{:__block__, _, [atom]}`; anything else (a computed tag, a
  # non-atom) is not a tag we reshape.
  @spec tag_name(Macro.t()) :: atom() | nil
  defp tag_name({:__block__, _meta, [atom]}) when is_atom(atom), do: atom
  defp tag_name(_other), do: nil
end
