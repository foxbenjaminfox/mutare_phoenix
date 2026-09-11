defmodule Mutare.Phoenix.Removal do
  # The shared plumbing for the fire-and-forget families (`ChannelMessage`, `PubSub`): a call
  # that sends a message and never returns its receiver is removed by collapsing it, whole,
  # to the `:ok` its happy path returns.
  @moduledoc false

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Mutator.Mutation

  # A family's call table: `function => {real arities, variant label}`. Only a real arity
  # fires, so a name-matched call of any other arity — reachable only by an explicit
  # qualifier, since the bare-import path resolves against a real arity — is left alone and
  # every metamutant keeps compiling.
  @type table :: %{atom() => {[arity(), ...], String.t()}}

  # The `:ok` removal for a call to `module` listed in `table`, tagged with the entry's
  # variant label; `:skip` for any other node.
  #
  # A piped call is left alone: none of these calls returns its first argument, so the
  # `Function.identity()` pass-through the socket-in socket-out families use would change the
  # value — and a pipe into the socket/pubsub slot is never idiomatic for a call that yields
  # `:ok` anyway.
  @doc false
  @spec removed(Macro.t(), module(), table(), Mutare.Mutator.pipe_mode()) ::
          :skip | [Mutation.t()]
  def removed(_node, _module, _table, :piped), do: :skip

  def removed(node, module, table, :unpiped) do
    with {:ok, fun, args, _rebuild} <- Calls.resolved_call_to(node, module, Map.keys(table)),
         {arities, label} = Map.fetch!(table, fun),
         true <- length(args) in arities do
      [Mutation.tagged(AST.literal(:ok), label)]
    else
      _other -> :skip
    end
  end
end
