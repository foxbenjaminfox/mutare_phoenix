defmodule Mutare.Phoenix.Plug do
  @moduledoc """
  `:plug_halt` — removes `Plug.Conn.halt/1`. A plug that fails to `halt` lets the request
  flow on to the action it meant to block, so a surviving `:plug_halt` mutant means no test
  depends on this plug halting.

      halt(conn)        # → conn
      conn |> halt()    # → conn |> Function.identity()

  Matches `halt` written directly (`Plug.Conn.halt(conn)`), aliased, or bare-imported
  (`halt(conn)`, the form `use MyAppWeb, :controller` / `:router` produces) — and only
  `Plug.Conn.halt/1`; a `halt` at any other arity is a different call and is left untouched.
  """
  @behaviour Mutare.Mutator

  alias Mutare.Transform.Calls

  @impl Mutare.Mutator
  @spec name() :: :plug_halt
  def name, do: :plug_halt

  # No `mutate/1`: whether removal returns the first arg (non-piped) or
  # `Function.identity()` (piped) depends on pipe context, unknowable from the node
  # alone — so this family produces only through the context-aware `mutate/2`.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    case Calls.resolved_call(node) do
      {[:Plug, :Conn], :halt, args, _rebuild} -> removed_call(pipe_mode, args)
      _other -> :skip
    end
  end

  # The pipe-aware removal, scoped to the real `Plug.Conn.halt/1` — the conn and nothing
  # else. A piped stage (`conn |> halt()`, no visible args) becomes the identity no-op; a
  # non-piped `halt(conn)` collapses to its lone argument, the conn. Any other shape — a
  # degenerate zero-arg `halt()`, or a wrong-arity `halt(conn, extra)` that isn't
  # `Plug.Conn.halt/1` at all — has no compile-safe removal and is skipped.
  @spec removed_call(Mutare.Mutator.pipe_mode(), [Macro.t()]) :: [Macro.t()] | :skip
  defp removed_call(:piped, []), do: [identity_call()]
  defp removed_call(:unpiped, [conn]), do: [conn]
  defp removed_call(_pipe_mode, _args), do: :skip

  # `Elixir.Function.identity()` — the `:Elixir`-led alias is never rewritten by alias
  # resolution, so the no-op always names the real `Function.identity/1`.
  @spec identity_call() :: Macro.t()
  defp identity_call,
    do: {{:., [], [{:__aliases__, [], [:"Elixir", :Function]}, :identity]}, [], []}
end
