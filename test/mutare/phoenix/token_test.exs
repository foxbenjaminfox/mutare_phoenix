defmodule Mutare.Phoenix.TokenTest do
  @moduledoc """
  `:token` — three variant-labelled kinds on the `Phoenix.Token` calls: `scheme` swaps a
  call for its sibling scheme (`sign` ↔ `encrypt`, `verify` ↔ `decrypt`), `payload` blanks a
  minting call's data to `nil`, and `expiry` turns an explicit integer `max_age:` of a
  reading call into `:infinity` (marking the position `:timeout` so the built-in integer
  family leaves the duration literal alone). Pipe-aware; matches direct, aliased, and
  bare-imported forms.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Phoenix.Token

  defp token_diffs(source), do: diffs_for(source, [Token], :token)

  defp mod(body), do: "defmodule Auth do\n#{body}\nend\n"

  describe "scheme: the sibling-scheme swap" do
    test "a qualified sign/3 becomes encrypt/3 (and its payload is blanked)" do
      assert token_diffs(mod("  def t(e, id), do: Phoenix.Token.sign(e, \"user\", id)")) == [
               {"Phoenix.Token.sign(e, \"user\", id)", "Phoenix.Token.encrypt(e, \"user\", id)"},
               {"Phoenix.Token.sign(e, \"user\", id)", "Phoenix.Token.sign(e, \"user\", nil)"}
             ]
    end

    test "each of the four calls swaps to its sibling" do
      body = """
        def t(e, id, tok) do
          Phoenix.Token.sign(e, "s", id, signed_at: 0)
          Phoenix.Token.encrypt(e, "s", id)
          Phoenix.Token.verify(e, "s", tok)
          Phoenix.Token.decrypt(e, "s", tok, max_age: 60)
        end\
      """

      schemes =
        for {original, mutated} <- token_diffs(mod(body)),
            not String.contains?(mutated, "nil") and not String.contains?(mutated, "infinity"),
            do: {original, mutated}

      assert schemes == [
               {"Phoenix.Token.sign(e, \"s\", id, signed_at: 0)",
                "Phoenix.Token.encrypt(e, \"s\", id, signed_at: 0)"},
               {"Phoenix.Token.encrypt(e, \"s\", id)", "Phoenix.Token.sign(e, \"s\", id)"},
               {"Phoenix.Token.verify(e, \"s\", tok)", "Phoenix.Token.decrypt(e, \"s\", tok)"},
               {"Phoenix.Token.decrypt(e, \"s\", tok, max_age: 60)",
                "Phoenix.Token.verify(e, \"s\", tok, max_age: 60)"}
             ]
    end

    test "an aliased Token.verify keeps its alias" do
      source = """
      defmodule Auth do
        alias Phoenix.Token
        def t(e, tok), do: Token.verify(e, "s", tok)
      end
      """

      assert token_diffs(source) == [
               {"Token.verify(e, \"s\", tok)", "Token.decrypt(e, \"s\", tok)"}
             ]
    end

    test "a bare imported verify is recognised" do
      source = """
      defmodule Auth do
        import Phoenix.Token
        def t(e, tok), do: verify(e, "s", tok)
      end
      """

      assert [{"verify(e, \"s\", tok)", mutated}] = token_diffs(source)
      assert mutated =~ ~r/decrypt\(e, "s", tok\)$/
    end
  end

  describe "payload: the minting call's data is blanked" do
    test "encrypt/4 blanks its data and keeps the options" do
      body = "  def t(e, u), do: Phoenix.Token.encrypt(e, \"s\", %{id: u.id}, signed_at: 0)"

      assert {"Phoenix.Token.encrypt(e, \"s\", %{id: u.id}, signed_at: 0)",
              "Phoenix.Token.encrypt(e, \"s\", nil, signed_at: 0)"} in token_diffs(mod(body))
    end

    test "an already-nil payload is left alone (the mutant would change nothing)" do
      assert token_diffs(mod("  def t(e), do: Phoenix.Token.sign(e, \"s\", nil)")) ==
               [{"Phoenix.Token.sign(e, \"s\", nil)", "Phoenix.Token.encrypt(e, \"s\", nil)"}]
    end

    test "a reading call has no payload to blank" do
      assert token_diffs(mod("  def t(e, tok), do: Phoenix.Token.verify(e, \"s\", tok)")) ==
               [{"Phoenix.Token.verify(e, \"s\", tok)", "Phoenix.Token.decrypt(e, \"s\", tok)"}]
    end
  end

  describe "expiry: an explicit max_age becomes :infinity" do
    test "verify/4 with a literal max_age gains the :infinity mutant" do
      body = "  def t(e, tok), do: Phoenix.Token.verify(e, \"s\", tok, max_age: 86_400)"

      assert token_diffs(mod(body)) == [
               {"Phoenix.Token.verify(e, \"s\", tok, max_age: 86_400)",
                "Phoenix.Token.decrypt(e, \"s\", tok, max_age: 86_400)"},
               {"Phoenix.Token.verify(e, \"s\", tok, max_age: 86_400)",
                "Phoenix.Token.verify(e, \"s\", tok, max_age: :infinity)"}
             ]
    end

    test "a bracketed options list keeps its other keys (the diff renders without brackets)" do
      body =
        "  def t(e, tok), do: Phoenix.Token.decrypt(e, \"s\", tok, [key_length: 32, max_age: 60])"

      assert {"Phoenix.Token.decrypt(e, \"s\", tok, key_length: 32, max_age: 60)",
              "Phoenix.Token.decrypt(e, \"s\", tok, key_length: 32, max_age: :infinity)"} in token_diffs(
               mod(body)
             )
    end

    test "a variable or :infinity max_age, or no options at all, is left alone" do
      body = """
        def t(e, tok, age) do
          Phoenix.Token.verify(e, "s", tok, max_age: age)
          Phoenix.Token.verify(e, "s", tok, max_age: :infinity)
          Phoenix.Token.verify(e, "s", tok, key_length: 32)
          Phoenix.Token.verify(e, "s", tok)
        end\
      """

      # Every mutant is a scheme swap; the `:infinity` site's swap carries the text along, so
      # check the variant labels rather than the rendered code.
      result = Mutare.transform_string(mod(body), mutators: [Token])

      assert Enum.map(result.mutants, & &1.variant) == List.duplicate(["scheme"], 4)
    end

    test "a minting call's options are not an expiry" do
      body = "  def t(e, id), do: Phoenix.Token.sign(e, \"s\", id, max_age: 60)"

      refute Enum.any?(token_diffs(mod(body)), fn {_o, m} -> m =~ "infinity" end)
    end
  end

  describe "the max_age is a marked :timeout position" do
    test "core's IntegerLiteral leaves the max_age literal alone when this family is enabled" do
      body = "  def t(e, tok), do: Phoenix.Token.verify(e, \"s\", tok, max_age: 86_400)"
      all = diffs(mod(body), [Mutare.Mutators.IntegerLiteral, Token])

      refute Enum.any?(all, fn {family, original, _m} ->
               family == :integer and original == "86_400"
             end)

      assert Enum.any?(all, fn {family, _o, mutated} ->
               family == :token and mutated =~ "max_age: :infinity"
             end)
    end

    test "control: without this family the max_age literal is mutated" do
      body = "  def t(e, tok), do: Phoenix.Token.verify(e, \"s\", tok, max_age: 86_400)"

      assert Enum.any?(diffs(mod(body), [Mutare.Mutators.IntegerLiteral]), fn {f, o, _m} ->
               f == :integer and o == "86_400"
             end)
    end

    test "core's AtomLiteral leaves an explicit :infinity alone too" do
      body = "  def t(e, tok), do: Phoenix.Token.verify(e, \"s\", tok, max_age: :infinity)"
      all = diffs(mod(body), [Mutare.Mutators.AtomLiteral, Token])

      refute Enum.any?(all, fn {family, original, _m} ->
               family == :atom and original == ":infinity"
             end)
    end
  end

  describe "variant labels (# mutare:ignore[token:<kind>])" do
    test "the declared vocabulary" do
      assert Token.variants() == ["scheme", "payload", "expiry"]
    end

    test "a qualified directive suppresses one kind and leaves the others live" do
      body =
        "  def t(e, tok), do: Phoenix.Token.verify(e, \"s\", tok, max_age: 60) # mutare:ignore[token:scheme]"

      result = Mutare.transform_string(mod(body), mutators: [Token])

      assert Enum.map(result.mutants, &{&1.variant, &1.ignored}) ==
               [{["scheme"], true}, {["expiry"], false}]
    end
  end

  describe "pipe awareness" do
    test "a piped sign finds the data at visible index 1" do
      assert token_diffs(mod("  def t(e, id), do: e |> Phoenix.Token.sign(\"s\", id)")) == [
               {"Phoenix.Token.sign(\"s\", id)", "Phoenix.Token.encrypt(\"s\", id)"},
               {"Phoenix.Token.sign(\"s\", id)", "Phoenix.Token.sign(\"s\", nil)"}
             ]
    end

    test "a piped verify/4 finds the options at visible index 2" do
      body = "  def t(e, tok), do: e |> Phoenix.Token.verify(\"s\", tok, max_age: 60)"

      assert {"Phoenix.Token.verify(\"s\", tok, max_age: 60)",
              "Phoenix.Token.verify(\"s\", tok, max_age: :infinity)"} in token_diffs(mod(body))
    end
  end

  describe "scope" do
    test "a wrong-arity qualified call is left alone (the arity guard)" do
      two = mod("  def t(e), do: Phoenix.Token.sign(e, \"s\")")
      five = mod("  def t(e, tok), do: Phoenix.Token.verify(e, \"s\", tok, [], :x)")

      assert token_diffs(two) == []
      assert token_diffs(five) == []
    end

    test "does not touch a same-named local sign (no import, no qualifier)" do
      source = """
      defmodule Auth do
        def t(e, id), do: sign(e, "s", id)
        def sign(_e, _s, _d), do: "tok"
      end
      """

      assert token_diffs(source) == []
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "a qualified sign yields the scheme swap and the blank payload" do
      assert node_mutations("Phoenix.Token.sign(e, \"s\", id)", Token) ==
               ["Phoenix.Token.encrypt(e, \"s\", id)", "Phoenix.Token.sign(e, \"s\", nil)"]
    end

    test "a piped verify stage node yields the swap and the expiry" do
      assert node_mutations("Phoenix.Token.verify(\"s\", t, max_age: 1)", Token, :piped) ==
               [
                 "Phoenix.Token.decrypt(\"s\", t, max_age: 1)",
                 "Phoenix.Token.verify(\"s\", t, max_age: :infinity)"
               ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule TokenCompileDemo do
      alias Phoenix.Token
      import Phoenix.Token, only: [decrypt: 4]

      @salt "user auth"

      def mint(endpoint, user) do
        token = Token.sign(endpoint, @salt, user.id)
        secret = Token.encrypt(endpoint, @salt, %{id: user.id}, signed_at: 0)
        {token, secret}
      end

      def read(endpoint, token, secret) do
        with {:ok, id} <- Token.verify(endpoint, @salt, token, max_age: 86_400),
             {:ok, %{id: ^id}} <- decrypt(endpoint, @salt, secret, [max_age: 60]) do
          {:ok, id}
        end
      end

      def piped(endpoint, id), do: endpoint |> Token.sign(@salt, id) |> String.length()
    end
    """

    assert_metamutant_compiles(source, [Token])
  end
end
