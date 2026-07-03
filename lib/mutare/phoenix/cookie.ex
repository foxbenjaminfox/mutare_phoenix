defmodule Mutare.Phoenix.Cookie do
  @moduledoc """
  `:resp_cookie` — removes response-cookie mutations and flips explicit `:same_site`
  cookie policy values. A survivor means no test depends on this code setting/deleting the
  response cookie, or on the cookie's SameSite policy.

      put_resp_cookie(conn, "sid", token)                    # → conn
      delete_resp_cookie(conn, "sid")                        # → conn
      put_resp_cookie(conn, "sid", token, same_site: "Lax")  # → "Strict" / "None"

  Matches `Plug.Conn.put_resp_cookie/3,4` and `Plug.Conn.delete_resp_cookie/2,3`
  written directly, aliased, or bare-imported. Boolean-valued cookie options such as
  `:secure` and `:http_only` are left to Mutare's built-in boolean mutators.
  """
  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Phoenix.ConnCall
  alias Mutare.Transform.Calls

  @removable MapSet.new([
               {[:Plug, :Conn], :put_resp_cookie, 3},
               {[:Plug, :Conn], :put_resp_cookie, 4},
               {[:Plug, :Conn], :delete_resp_cookie, 2},
               {[:Plug, :Conn], :delete_resp_cookie, 3}
             ])

  # The options argument for the arity-carrying forms:
  #   put_resp_cookie(conn, key, value, opts) => effective option index 3
  #   delete_resp_cookie(conn, key, opts)     => effective option index 2
  @same_site_calls %{
    put_resp_cookie: {4, 3},
    delete_resp_cookie: {3, 2}
  }

  @same_site_swaps %{
    "Lax" => ["Strict", "None"],
    "Strict" => ["Lax", "None"],
    "None" => ["Lax", "Strict"]
  }

  @impl Mutare.Mutator
  @spec name() :: :resp_cookie
  def name, do: :resp_cookie

  # No `mutate/1`: removal and option position both depend on pipe context.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    combine_mutations(
      ConnCall.remove(node, pipe_mode, @removable),
      same_site_mutations(node, pipe_mode)
    )
  end

  defp same_site_mutations(node, pipe_mode) do
    case Calls.resolved_call(node) do
      {[:Plug, :Conn], call, args, rebuild} when is_map_key(@same_site_calls, call) ->
        same_site_mutations(call, args, pipe_mode, rebuild)

      _other ->
        :skip
    end
  end

  defp same_site_mutations(call, args, pipe_mode, rebuild) do
    {expected_arity, option_index} = Map.fetch!(@same_site_calls, call)

    with ^expected_arity <- Mutare.Mutator.effective_arity(args, pipe_mode),
         vis when is_integer(vis) <- Mutare.Mutator.visible_index(option_index, pipe_mode),
         [_ | _] = options <- same_site_option_mutations(Enum.at(args, vis), args, vis) do
      Enum.map(options, fn mutated_args -> rebuild.(call, mutated_args) end)
    else
      _other -> :skip
    end
  end

  defp same_site_option_mutations(arg, args, option_visible_index) do
    case keyword_list(arg) do
      nil ->
        []

      {pairs, rewrap} ->
        for {{key, value}, i} <- Enum.with_index(pairs),
            AST.key_atom(key) == :same_site,
            current <- same_site_value(value),
            mutation <-
              same_site_pair_mutations(
                pairs,
                i,
                value,
                current,
                rewrap,
                args,
                option_visible_index
              ) do
          mutation
        end
    end
  end

  defp same_site_pair_mutations(pairs, index, value, current, rewrap, args, option_visible_index) do
    maybe_drop_same_site(pairs, index, current, rewrap, args, option_visible_index) ++
      flipped_same_site(pairs, index, value, current, rewrap, args, option_visible_index)
  end

  # Dropping `same_site: "Lax"` is usually equivalent to Plug's default, so only remove an
  # explicit policy when the written value differs from that default.
  defp maybe_drop_same_site(_pairs, _index, "Lax", _rewrap, _args, _option_visible_index), do: []

  defp maybe_drop_same_site(pairs, index, _current, rewrap, args, option_visible_index) do
    case List.delete_at(pairs, index) do
      [] -> [List.delete_at(args, option_visible_index)]
      remaining -> [List.replace_at(args, option_visible_index, rewrap.(remaining))]
    end
  end

  defp flipped_same_site(pairs, index, value, current, rewrap, args, option_visible_index) do
    for sibling <- Map.get(@same_site_swaps, current, []) do
      pairs
      |> List.replace_at(index, replace_value(pairs, index, value, sibling))
      |> then(&List.replace_at(args, option_visible_index, rewrap.(&1)))
    end
  end

  defp replace_value(pairs, index, value, sibling) do
    {key, _old_value} = Enum.at(pairs, index)
    {key, swap_literal(value, sibling)}
  end

  defp keyword_list({:__block__, meta, [inner]}) when is_list(inner) do
    with pairs when pairs != nil <- keyword_pairs(inner),
         do: {pairs, fn new -> {:__block__, meta, [new]} end}
  end

  defp keyword_list(list) when is_list(list) do
    with pairs when pairs != nil <- keyword_pairs(list), do: {pairs, & &1}
  end

  defp keyword_list(_arg), do: nil

  defp keyword_pairs(list) when is_list(list) and list != [] do
    if Enum.all?(list, &match?({_key, _value}, &1)), do: list, else: nil
  end

  defp keyword_pairs(_list), do: nil

  defp same_site_value(node) do
    case AST.literal_value(node) do
      {:ok, value} when is_binary(value) -> [value]
      _other -> []
    end
  end

  defp swap_literal({:__block__, meta, [_old]}, value), do: {:__block__, meta, [value]}
  defp swap_literal(_old, value), do: AST.literal(value)

  defp combine_mutations(left, right) do
    case mutation_list(left) ++ mutation_list(right) do
      [] -> :skip
      mutations -> mutations
    end
  end

  defp mutation_list(:skip), do: []
  defp mutation_list(mutations) when is_list(mutations), do: mutations
end
