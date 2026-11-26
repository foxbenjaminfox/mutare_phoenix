defmodule Mutare.Phoenix.Options do
  @moduledoc false

  alias Mutare.AST

  @typep replace :: (atom() -> Macro.t())

  # Follow Keyword.get/3's first-match rule and keep the rest of the list intact.
  # An explicit bracketed list carries a Sourceror block wrapper that we restore.
  @doc false
  @spec fetch_first(Macro.t(), atom()) :: {:ok, Macro.t(), replace()} | :error
  def fetch_first({:__block__, meta, [pairs]}, name) when is_list(pairs) do
    fetch_pair(pairs, name, fn new -> {:__block__, meta, [new]} end)
  end

  def fetch_first(pairs, name) when is_list(pairs), do: fetch_pair(pairs, name, & &1)
  def fetch_first(_arg, _name), do: :error

  defp fetch_pair(pairs, name, rewrap) do
    with {before, [{key, value} | rest]} <-
           Enum.split_while(pairs, &different_literal_key?(&1, name)),
         {:ok, ^name} <- AST.literal_value(key),
         true <- Enum.all?(rest, &match?({_key, _value}, &1)) do
      replace = fn new -> rewrap.(before ++ [{key, swap_literal(value, new)} | rest]) end
      {:ok, value, replace}
    else
      _other -> :error
    end
  end

  # Stop at a computed key, which could shadow a later literal at runtime.
  defp different_literal_key?({key, _value}, name) do
    match?({:ok, atom} when is_atom(atom) and atom != name, AST.literal_value(key))
  end

  defp different_literal_key?(_entry, _name), do: false

  # Keep Sourceror metadata so a multi-argument call still renders inline.
  defp swap_literal({:__block__, meta, [_old]}, value), do: {:__block__, meta, [value]}
  defp swap_literal(_bare, value), do: AST.literal(value)
end
