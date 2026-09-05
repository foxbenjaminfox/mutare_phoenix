defmodule Mutare.Phoenix.Download do
  @moduledoc """
  `:download_disposition` — flips the explicit `:disposition` option of
  `Phoenix.Controller.send_download/3` between `:attachment` and `:inline`. A surviving
  mutant means no test pins whether the browser is told to *save* the file or *display*
  it — the type in the `content-disposition` header.

      send_download(conn, {:file, path}, disposition: :attachment)   # → :inline
      conn |> send_download({:binary, csv}, filename: "r.csv", disposition: :inline)
      #                                                                     ↳ :attachment

  Only an explicit literal atom is flipped: a `send_download` that relies on Phoenix's
  default (`:attachment`), or passes a variable, is left alone — as is `send_download/2`,
  which has no options at all. Matches the call written directly
  (`Phoenix.Controller.send_download(conn, ...)`), aliased, or bare-imported
  (`send_download(conn, ...)`, the form `use MyAppWeb, :controller` produces).

  The swap substitutes exactly the disposition atom, so `Mutare.Transform.Overlap` prunes
  the built-in `:atom` family's `:mutare` leaf at that range — which would only crash
  (Phoenix rejects any disposition other than `:attachment` / `:inline`), an uninformative
  kill.
  """
  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Phoenix.Options

  # The two disposition types Phoenix accepts, each the other's flip.
  @flips %{attachment: :inline, inline: :attachment}

  # The options are the third effective argument of `send_download/3`.
  @options_index 2

  @impl Mutare.Mutator
  @spec name() :: :download_disposition
  def name, do: :download_disposition

  # No `mutate/1`: the options list's visible index depends on pipe context.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    case Calls.resolved_call(node) do
      {[:Phoenix, :Controller], :send_download, args, rebuild} ->
        disposition_mutations(args, pipe_mode, rebuild)

      _other ->
        :skip
    end
  end

  # The `:disposition` option lives in the third effective argument of `send_download/3`:
  # `send_download(conn, kind, disposition: :inline)`, or visible index 1 in a pipe stage.
  # Anything that is not exactly `send_download/3`, or whose options are not a literal
  # keyword list, is skipped.
  @spec disposition_mutations(
          [Macro.t()],
          Mutare.Mutator.pipe_mode(),
          (atom(), [Macro.t()] -> Macro.t())
        ) :: :skip | [Macro.t()]
  defp disposition_mutations(args, pipe_mode, rebuild) do
    with 3 <- Mutare.Mutator.effective_arity(args, pipe_mode),
         vis when is_integer(vis) <- Mutare.Mutator.visible_index(@options_index, pipe_mode),
         [_ | _] = options <- disposition_flips(Enum.at(args, vis)) do
      Enum.map(options, &rebuild.(:send_download, List.replace_at(args, vis, &1)))
    else
      _other -> :skip
    end
  end

  # For every literal `disposition: atom` pair whose atom has a flip, one rebuilt options
  # list with just that value changed — keeping the value node's position metadata (see
  # `Options.swap_literal/2`) so the call renders as a minimal inline diff.
  @spec disposition_flips(Macro.t()) :: [Macro.t()]
  defp disposition_flips(arg) do
    case Options.keyword_list(arg) do
      nil ->
        []

      {pairs, rewrap} ->
        for {{key, value}, i} <- Enum.with_index(pairs),
            Options.key?(key, :disposition),
            current <- Options.atom_literal(value),
            flipped <- List.wrap(Map.get(@flips, current)) do
          rewrap.(List.replace_at(pairs, i, {key, Options.swap_literal(value, flipped)}))
        end
    end
  end
end
