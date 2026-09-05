defmodule Mutare.Phoenix.Body do
  @moduledoc """
  `:controller_body` — blanks a rendered response body: the data argument of
  `Phoenix.Controller.json/2` becomes `%{}`, and that of `text/2` and `html/2` becomes
  `""`. A surviving mutant means no test reads the response body — the action answered,
  with the right status and content type, and nothing checked what it said.

      json(conn, %{id: user.id})        # → json(conn, %{})
      text(conn, "pong")                # → text(conn, "")
      conn |> html(render_page(page))   # → conn |> html("")

  The blank is the emptiest value each renderer still sends cleanly: `%{}` encodes to
  `{}` — a well-formed, empty JSON document — while `""` is a `text`/`html` body with
  nothing in it. A body that is already that blank literal is left alone (the mutant would
  change nothing).

  Matches each call written directly (`Phoenix.Controller.json(conn, ...)`), aliased, or
  bare-imported (`json(conn, ...)`, the form `use MyAppWeb, :controller` produces). The
  `Plug.Conn`-level bodies (`send_resp/3`, `resp/3`) are `mutare_plug`'s `:resp_body`;
  `render/3` is out of scope — its argument names a template, not a body.

  Because the mutation is the original call with exactly the body argument substituted,
  `Mutare.Transform.Overlap` treats it as covering that node: on a *literal* `text`/`html`
  body the built-in `:string` leaves (`""`/`"mutare"`) are pruned automatically, so this
  family supersedes them rather than double-firing on the same range. A `json` map
  literal's *entries* are descendants, not the body node, so the built-in mutators keep
  their own mutants inside it.
  """
  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls

  # The `Phoenix.Controller` renderers that take a body, each with its blank. In all three
  # the body sits at effective argument index 1 — the second positional argument — and the
  # arity is fixed at 2, so a wrong-arity call (not the real function) contributes nothing.
  @blanks %{json: %{}, text: "", html: ""}

  @body_index 1

  @impl Mutare.Mutator
  @spec name() :: :controller_body
  def name, do: :controller_body

  # No `mutate/1`: the body's visible position depends on pipe context, so this family
  # produces only through the context-aware `mutate/2`.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    case Calls.resolved_call(node) do
      {[:Phoenix, :Controller], call, args, rebuild} when is_map_key(@blanks, call) ->
        body_mutations(call, args, pipe_mode, rebuild)

      _other ->
        :skip
    end
  end

  @spec body_mutations(
          atom(),
          [Macro.t()],
          Mutare.Mutator.pipe_mode(),
          (atom(), [Macro.t()] -> Macro.t())
        ) :: :skip | [Macro.t()]
  defp body_mutations(call, args, pipe_mode, rebuild) do
    blank = Map.fetch!(@blanks, call)

    with 2 <- Mutare.Mutator.effective_arity(args, pipe_mode),
         vis when is_integer(vis) <- Mutare.Mutator.visible_index(@body_index, pipe_mode),
         body = Enum.at(args, vis),
         false <- blank?(body, blank) do
      [rebuild.(call, List.replace_at(args, vis, blank_body(body, blank)))]
    else
      _other -> :skip
    end
  end

  # Already-blank bodies produce nothing: replacing a blank with itself is a no-op mutant.
  @spec blank?(Macro.t(), %{} | String.t()) :: boolean()
  defp blank?({:%{}, _meta, []}, %{}), do: true
  defp blank?(_body, %{}), do: false
  defp blank?(body, ""), do: AST.literal_value(body) == {:ok, ""}

  # Blank the body inside the original node, keeping its Sourceror metadata when the body
  # is a wrapped string literal — the clean-meta rule: change the value, keep the position,
  # so the call re-renders inline. Anything else (a variable, a call, an interpolated
  # string, a map literal) is replaced wholesale by a fresh blank node.
  @spec blank_body(Macro.t(), %{} | String.t()) :: Macro.t()
  defp blank_body(_body, %{}), do: {:%{}, [], []}

  defp blank_body({:__block__, meta, [body]}, "") when is_binary(body),
    do: {:__block__, meta, [""]}

  defp blank_body(_body, ""), do: AST.literal("")
end
