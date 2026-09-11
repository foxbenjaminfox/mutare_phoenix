defmodule Mutare.Phoenix.Token do
  @moduledoc """
  `:token` — mutates the `Phoenix.Token` calls that mint and read signed or encrypted
  tokens. Three kinds, each a variant label:

  **`scheme`** swaps the call for its sibling scheme — `sign/3,4` ↔ `encrypt/3,4`,
  `verify/3,4` ↔ `decrypt/3,4` — so a token minted at the mutated site no longer round-trips
  through its partner:

      Phoenix.Token.sign(endpoint, "user auth", user.id)     ->  Phoenix.Token.encrypt(...)
      Phoenix.Token.verify(endpoint, "user auth", token)     ->  Phoenix.Token.decrypt(...)

  A survivor means no test ever verifies a token this site signed (or decrypts one it
  encrypted, or feeds a real token into this reader) — the email is asserted to contain a
  link, say, and the link is never followed.

  **`payload`** blanks the data a `sign`/`encrypt` call embeds, to `nil`:

      Phoenix.Token.sign(endpoint, "user auth", user.id)     ->  Phoenix.Token.sign(endpoint, "user auth", nil)

  A survivor means the token still verifies but no test checks *what* it carries — a
  `{:ok, _} = verify(...)` that never compares the payload.

  **`expiry`** disables the explicit `max_age:` of a `verify`/`decrypt` call:

      Phoenix.Token.verify(endpoint, salt, token, max_age: 86_400)  ->  max_age: :infinity

  A survivor means no test presents an expired token. Only an explicit integer literal is
  mutated; a call relying on Phoenix's default (one day), or passing a variable or
  `:infinity`, is left alone. The position is marked with the shared `:timeout` label
  (`c:Mutare.Mutator.argument_marks/1`), so Mutare's built-in `:integer` family leaves the
  duration literal alone — this kind owns the expiry question, and an `86_400 → 86_401`
  off-by-one there is the near-unkillable noise that family's own timeout table exists to
  avoid (and `:atom` leaves an explicit `:infinity` alone for the same reason).

  Suppress one kind with `# mutare:ignore[token:expiry]`, or the whole family with
  `# mutare:ignore[token]`. The salt is not this family's axis: a literal salt is Mutare's
  built-in `:string` family, and a salt held in a module attribute is compile-time data core
  never mutates.

  Only the real arities fire — 3 and 4 for all four calls — so a name-matched call of any
  other arity (reachable only by an explicit qualifier) is left alone, keeping every
  metamutant compiling. The context argument (an endpoint, conn, or socket) is the first
  effective argument, so a piped call (`endpoint |> Phoenix.Token.sign(salt, data)`) is
  handled through pipe context. Matches direct (`Phoenix.Token.sign(...)`), aliased, and
  bare-imported calls.
  """
  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation
  alias Mutare.Phoenix.Options

  # The `rebuild` closure `Calls.resolved_call_to/3` hands back: re-emits the call in its
  # written form with a new function name and argument list.
  @typep rebuild :: (atom(), [Macro.t()] -> Macro.t())

  # Each call's sibling scheme. The pairs share a signature — `(context, salt_or_secret,
  # data_or_token, opts \\ [])` — so the swap is a rename with the arguments kept.
  @schemes %{sign: :encrypt, encrypt: :sign, verify: :decrypt, decrypt: :verify}

  # The minting calls carry the data at effective index 2; the reading calls carry the
  # options (with `max_age:`) at effective index 3, present only at arity 4.
  @minters [:sign, :encrypt]
  @readers [:verify, :decrypt]
  @arities [3, 4]
  @data_index 2
  @options_index 3

  @impl Mutare.Mutator
  @spec name() :: :token
  def name, do: :token

  # Variant vocabulary for `# mutare:ignore[token:<kind>]`, tagged at production.
  @impl Mutare.Mutator
  @spec variants() :: [String.t()]
  def variants, do: ~w(scheme payload expiry)

  # The `max_age:` option of `verify/4` and `decrypt/4` is a duration in seconds — a TTL,
  # exactly what core's `IntegerLiteral` timeout table pins for `Process.send_after` and
  # friends. The shared `:timeout` label is what `IntegerLiteral` (and `AtomLiteral`, for
  # `:infinity`) react to; the `expiry` kind owns the question instead.
  @impl Mutare.Mutator
  @spec argument_marks(term()) :: [Mutator.mark_declaration()]
  def argument_marks(_config) do
    for reader <- @readers, do: {Phoenix.Token, reader, 4, [{:keyword, :max_age}], :timeout}
  end

  # No `mutate/1`: the data and options positions are non-first effective arguments whose
  # visible index depends on pipe context, and the arity guard needs it too.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutator.context()) :: :skip | [Mutation.t()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    with {:ok, fun, args, rebuild} <-
           Calls.resolved_call_to(node, Phoenix.Token, Map.keys(@schemes)),
         true <- Mutator.effective_arity(args, pipe_mode) in @arities do
      scheme(fun, args, rebuild) ++
        payload(fun, args, pipe_mode, rebuild) ++ expiry(fun, args, pipe_mode, rebuild)
    else
      _other -> :skip
    end
  end

  # The sibling-scheme rename, arguments untouched.
  @spec scheme(atom(), [Macro.t()], rebuild()) :: [Mutation.t()]
  defp scheme(fun, args, rebuild),
    do: [Mutation.tagged(rebuild.(Map.fetch!(@schemes, fun), args), "scheme")]

  # Blank a minting call's data to `nil` — unless it already is, where the mutant would
  # change nothing. The data is replaced wholesale by a fresh literal: it is usually a
  # variable or a call, not a wrapped literal whose metadata is worth keeping.
  @spec payload(atom(), [Macro.t()], Mutator.pipe_mode(), rebuild()) :: [Mutation.t()]
  defp payload(fun, args, pipe_mode, rebuild) when fun in @minters do
    with vis when is_integer(vis) <- Mutator.visible_index(@data_index, pipe_mode),
         data = Enum.at(args, vis),
         false <- AST.literal_value(data) == {:ok, nil} do
      blanked = rebuild.(fun, List.replace_at(args, vis, AST.literal(nil)))
      [Mutation.tagged(blanked, "payload")]
    else
      _other -> []
    end
  end

  defp payload(_fun, _args, _pipe_mode, _rebuild), do: []

  # For every literal integer `max_age:` in a reader's options, one rebuilt call with just
  # that value swapped to `:infinity` — keeping the value node's position metadata (see
  # `Options.swap_literal/2`) so the call renders as a minimal inline diff.
  @spec expiry(atom(), [Macro.t()], Mutator.pipe_mode(), rebuild()) :: [Mutation.t()]
  defp expiry(fun, args, pipe_mode, rebuild) when fun in @readers do
    with 4 <- Mutator.effective_arity(args, pipe_mode),
         vis when is_integer(vis) <- Mutator.visible_index(@options_index, pipe_mode),
         {pairs, rewrap} <- Options.keyword_list(Enum.at(args, vis)) do
      for {{key, value}, i} <- Enum.with_index(pairs),
          Options.key?(key, :max_age),
          match?({:ok, seconds} when is_integer(seconds), AST.literal_value(value)) do
        pair = {key, Options.swap_literal(value, :infinity)}
        opts = rewrap.(List.replace_at(pairs, i, pair))
        Mutation.tagged(rebuild.(fun, List.replace_at(args, vis, opts)), "expiry")
      end
    else
      _other -> []
    end
  end

  defp expiry(_fun, _args, _pipe_mode, _rebuild), do: []
end
