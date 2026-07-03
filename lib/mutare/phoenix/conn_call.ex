defmodule Mutare.Phoenix.ConnCall do
  @moduledoc false

  alias Mutare.AST
  alias Mutare.Transform.Calls

  @typep module_key :: [atom()] | atom()
  @typep removable_call :: {module_key(), atom(), arity()}

  @doc false
  @spec remove(
          Macro.t(),
          Mutare.Mutator.pipe_mode(),
          MapSet.t(removable_call())
        ) :: :skip | [Macro.t()]
  def remove(node, pipe_mode, removable) do
    with {module, call, args, _rebuild} <- Calls.resolved_call(node),
         effective_arity when is_integer(effective_arity) <-
           Mutare.Mutator.effective_arity(args, pipe_mode),
         true <- MapSet.member?(removable, {module, call, effective_arity}) do
      removed_call(pipe_mode, args)
    else
      _other -> :skip
    end
  end

  @doc false
  @spec removed_call(Mutare.Mutator.pipe_mode(), [Macro.t()]) :: :skip | [Macro.t()]
  def removed_call(:piped, _args), do: [AST.absolute_call([:Function], :identity, [])]
  def removed_call(:unpiped, []), do: :skip
  def removed_call(:unpiped, [conn | _rest]), do: [conn]
end
