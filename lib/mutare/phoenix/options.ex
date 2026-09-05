defmodule Mutare.Phoenix.Options do
  # The shared keyword-options plumbing for the families that mutate a call's trailing
  # options (`Redirect`'s `status:`, `Download`'s `disposition:`): read the `{key, value}`
  # pairs out of an options argument in either written shape, and put a mutated pair list
  # back in the same shape.
  @moduledoc false

  alias Mutare.AST

  # Restores a mutated pair list to the argument's original written shape.
  @type rewrap :: ([Macro.t()] -> Macro.t())

  # A bare trailing keyword list (`redirect(conn, to: "/", status: :found)`) arrives as the
  # pair list itself; an explicit bracketed list (`redirect(conn, [to: "/"])`) arrives
  # Sourceror-wrapped in a `:__block__`, and `rewrap` restores that wrapper. Anything that
  # is not a non-empty list of `{key, value}` pairs — a variable, a map, `[]` — is `nil`.
  @doc false
  @spec keyword_list(Macro.t()) :: {[{Macro.t(), Macro.t()}], rewrap()} | nil
  def keyword_list({:__block__, meta, [inner]}) when is_list(inner) do
    with pairs when pairs != nil <- keyword_pairs(inner),
         do: {pairs, fn new -> {:__block__, meta, [new]} end}
  end

  def keyword_list(list) when is_list(list) do
    with pairs when pairs != nil <- keyword_pairs(list), do: {pairs, & &1}
  end

  def keyword_list(_arg), do: nil

  defp keyword_pairs(list) when is_list(list) and list != [] do
    if Enum.all?(list, &match?({_key, _value}, &1)), do: list, else: nil
  end

  defp keyword_pairs(_list), do: nil

  # Whether a pair's key node names `atom`.
  @doc false
  @spec key?(Macro.t(), atom()) :: boolean()
  def key?(key, atom), do: AST.key_atom(key) == atom

  # The atom a value node literally names, as a zero-or-one list for comprehension use.
  # `true`/`false`/`nil` never name an option kind, so they yield nothing.
  @doc false
  @spec atom_literal(Macro.t()) :: [atom()]
  def atom_literal(node) do
    case AST.literal_value(node) do
      {:ok, atom} when is_atom(atom) and atom not in [true, false, nil] -> [atom]
      _other -> []
    end
  end

  # Swap the literal inside the original value node, keeping its Sourceror metadata — the
  # clean-meta rule: change the value, keep the position, so a multi-argument call
  # re-renders inline. A bare (unwrapped) node has no metadata to keep and gets a fresh
  # literal.
  @doc false
  @spec swap_literal(Macro.t(), term()) :: Macro.t()
  def swap_literal({:__block__, meta, [_old]}, value), do: {:__block__, meta, [value]}
  def swap_literal(_bare, value), do: AST.literal(value)
end
