defmodule Mutare.Phoenix.Session do
  @moduledoc """
  `:plug_session` — removes `Plug.Conn` session mutations. A surviving mutant means no test
  depends on this code writing, deleting, or clearing session state.

      put_session(conn, :user_id, user.id)  # → conn
      conn |> delete_session(:user_id)      # → conn |> Function.identity()
      clear_session(conn)                   # → conn

  Matches `put_session/3`, `delete_session/2`, and `clear_session/1` written directly
  (`Plug.Conn.put_session(conn, ...)`), aliased, or bare-imported. Boolean-valued session
  options such as `configure_session(renew: true)` are left to Mutare's built-in boolean
  mutators.
  """
  @behaviour Mutare.Mutator

  alias Mutare.Phoenix.ConnCall

  @removable MapSet.new([
               {[:Plug, :Conn], :put_session, 3},
               {[:Plug, :Conn], :delete_session, 2},
               {[:Plug, :Conn], :clear_session, 1}
             ])

  @impl Mutare.Mutator
  @spec name() :: :plug_session
  def name, do: :plug_session

  # No `mutate/1`: removal shape depends on pipe context.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}), do: ConnCall.remove(node, pipe_mode, @removable)
end
