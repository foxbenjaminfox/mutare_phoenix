defmodule Mutare.Phoenix.Redirect do
  @moduledoc """
  `:redirect_status` — swaps the explicit atom `:status` option of
  `Phoenix.Controller.redirect/2` for a plausible redirect-status sibling.

      redirect(conn, to: "/login", status: :found)  # → :moved_permanently / :see_other
      redirect(conn, to: "/old", status: :moved_permanently)  # → :found / :permanent_redirect

  Integer statuses (`status: 302`), variables (`status: status`), and redirects that rely on
  Phoenix's implicit default are left alone. Matches `redirect` written directly
  (`Phoenix.Controller.redirect(conn, ...)`), aliased, or bare-imported (`redirect(conn, ...)`,
  the form `use MyAppWeb, :controller` produces).
  """
  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Phoenix.Options

  # The redirect status atoms Phoenix accepts in ordinary Location-based redirects, excluding
  # non-Location 3xx statuses such as :not_modified. Swaps stay within valid redirect statuses:
  # temporary/permanent, 302/303, and method-preserving/non-method-preserving distinctions.
  @status_swaps %{
    moved_permanently: [:found, :permanent_redirect],
    found: [:moved_permanently, :see_other],
    see_other: [:found],
    temporary_redirect: [:found, :permanent_redirect],
    permanent_redirect: [:moved_permanently, :temporary_redirect]
  }

  # The options are the second effective argument of `redirect/2`.
  @options_index 1

  @impl Mutare.Mutator
  @spec name() :: :redirect_status
  def name, do: :redirect_status

  # No `mutate/1`: the options list is the second effective argument of `redirect/2`, so its
  # visible index depends on pipe context.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    case Calls.resolved_call(node) do
      {[:Phoenix, :Controller], :redirect, args, rebuild} ->
        redirect_status_mutations(args, pipe_mode, rebuild)

      _other ->
        :skip
    end
  end

  # The `:status` option lives in the second effective argument of `redirect/2`:
  # `redirect(conn, status: :found, to: "/")`, or visible index 0 in a pipe stage
  # (`conn |> redirect(status: :found, to: "/")`). Anything that is not exactly
  # `redirect/2`, or whose options are not a literal keyword list, is skipped.
  @spec redirect_status_mutations(
          [Macro.t()],
          Mutare.Mutator.pipe_mode(),
          (atom(), [Macro.t()] -> Macro.t())
        ) :: :skip | [Macro.t()]
  defp redirect_status_mutations(args, pipe_mode, rebuild) do
    with 2 <- Mutare.Mutator.effective_arity(args, pipe_mode),
         vis when is_integer(vis) <- Mutare.Mutator.visible_index(@options_index, pipe_mode),
         [_ | _] = options <- status_option_swaps(Enum.at(args, vis)) do
      Enum.map(options, fn opts -> rebuild.(:redirect, List.replace_at(args, vis, opts)) end)
    else
      _ -> :skip
    end
  end

  # A redirect-status option: the atom sits as the *value* of the `status:` key in the
  # trailing options list. For every literal `status: atom` whose atom has curated siblings,
  # emit one rebuilt options list with just that value changed — the swap keeps the value
  # node's position metadata (see `Options.swap_literal/2`), so a multi-option call renders
  # as a minimal inline diff.
  @spec status_option_swaps(Macro.t()) :: [Macro.t()]
  defp status_option_swaps(arg) do
    case Options.keyword_list(arg) do
      nil ->
        []

      {pairs, rewrap} ->
        for {{key, value}, i} <- Enum.with_index(pairs),
            Options.key?(key, :status),
            status <- Options.atom_literal(value),
            new_status <- Map.get(@status_swaps, status, []) do
          rewrap.(List.replace_at(pairs, i, {key, Options.swap_literal(value, new_status)}))
        end
    end
  end
end
