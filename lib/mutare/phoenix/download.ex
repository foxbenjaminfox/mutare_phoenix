defmodule Mutare.Phoenix.Download do
  @moduledoc """
  `:download_disposition` — flips the explicit `:disposition` option of
  `Phoenix.Controller.send_download/3` between `:attachment` and `:inline`. A surviving
  mutant means no test checks whether the response specifies *saving* or *displaying*
  the file — the type in the `content-disposition` header.

      send_download(conn, {:file, path}, disposition: :attachment)   # → :inline
      conn |> send_download({:binary, csv}, filename: "r.csv", disposition: :inline)
      #                                                                     ↳ :attachment

  The first `disposition:` entry is eligible when it contains an explicit atom literal.
  Phoenix uses its default (`:attachment`) when the option is omitted. Matches qualified
  calls (`Phoenix.Controller.send_download(conn, ...)`), aliased calls, and bare imports
  (`send_download(conn, ...)`, the form `use MyAppWeb, :controller` produces).

  The swap substitutes exactly the disposition atom, so `Mutare.Transform.Overlap` prunes
  the built-in `:atom` family's `:mutare` leaf at that range — which would only crash
  (Phoenix rejects any disposition other than `:attachment` / `:inline`), an uninformative
  kill.
  """
  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Phoenix.Options

  # The two disposition types Phoenix accepts, each the other's flip.
  @flips %{attachment: :inline, inline: :attachment}

  @impl Mutare.Mutator
  @spec name() :: :download_disposition
  def name, do: :download_disposition

  @impl Mutare.Mutator
  @spec mutate(Macro.t()) :: :skip | [Macro.t()]
  def mutate(node) do
    with {:ok, :send_download, [conn, kind, opts], rebuild} <-
           Calls.resolved_call_to(node, Phoenix.Controller, :send_download),
         {:ok, value, replace} <- Options.fetch_first(opts, :disposition),
         {:ok, current} <- AST.literal_value(value),
         {:ok, flipped} <- Map.fetch(@flips, current) do
      [rebuild.(:send_download, [conn, kind, replace.(flipped)])]
    else
      _other -> :skip
    end
  end
end
