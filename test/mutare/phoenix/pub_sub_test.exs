defmodule Mutare.Phoenix.PubSubTest do
  @moduledoc """
  `:pubsub` — three variant-labelled removals on the `Phoenix.PubSub` calls, each collapsing
  the call to the `:ok` its happy path returns: `subscribe`, `unsubscribe`, and `broadcast`
  (the whole `broadcast`/`broadcast!`/`broadcast_from`/`local_broadcast`/`direct_broadcast`
  surface). Matches direct, aliased, and bare-imported forms; the never-idiomatic piped form
  is left alone.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Phoenix.PubSub

  defp pubsub_diffs(source), do: diffs_for(source, [PubSub], :pubsub)

  defp live(body), do: "defmodule MyLive do\n#{body}\nend\n"

  describe "removal across written forms" do
    test "a qualified Phoenix.PubSub.subscribe collapses to :ok" do
      source = live("  def go, do: Phoenix.PubSub.subscribe(MyApp.PubSub, \"room:1\")")

      assert pubsub_diffs(source) == [
               {"Phoenix.PubSub.subscribe(MyApp.PubSub, \"room:1\")", ":ok"}
             ]
    end

    test "an aliased PubSub.broadcast collapses to :ok" do
      source = """
      defmodule L do
        alias Phoenix.PubSub
        def go, do: PubSub.broadcast(MyApp.PubSub, "room:1", {:new, 1})
      end
      """

      assert pubsub_diffs(source) ==
               [{"PubSub.broadcast(MyApp.PubSub, \"room:1\", {:new, 1})", ":ok"}]
    end

    test "a bare imported unsubscribe collapses to :ok" do
      source = """
      defmodule L do
        import Phoenix.PubSub
        def go, do: unsubscribe(MyApp.PubSub, "room:1")
      end
      """

      assert pubsub_diffs(source) == [{"unsubscribe(MyApp.PubSub, \"room:1\")", ":ok"}]
    end

    test "every call fires at each real arity, tagged with its kind" do
      body = """
        def go(t, m, d) do
          Phoenix.PubSub.subscribe(P, t)
          Phoenix.PubSub.subscribe(P, t, metadata: :x)
          Phoenix.PubSub.unsubscribe(P, t)
          Phoenix.PubSub.broadcast(P, t, m)
          Phoenix.PubSub.broadcast(P, t, m, d)
          Phoenix.PubSub.broadcast!(P, t, m)
          Phoenix.PubSub.broadcast!(P, t, m, d)
          Phoenix.PubSub.broadcast_from(P, self(), t, m)
          Phoenix.PubSub.broadcast_from(P, self(), t, m, d)
          Phoenix.PubSub.broadcast_from!(P, self(), t, m)
          Phoenix.PubSub.broadcast_from!(P, self(), t, m, d)
          Phoenix.PubSub.local_broadcast(P, t, m)
          Phoenix.PubSub.local_broadcast(P, t, m, d)
          Phoenix.PubSub.local_broadcast_from(P, self(), t, m)
          Phoenix.PubSub.local_broadcast_from(P, self(), t, m, d)
          Phoenix.PubSub.direct_broadcast(node(), P, t, m)
          Phoenix.PubSub.direct_broadcast(node(), P, t, m, d)
          Phoenix.PubSub.direct_broadcast!(node(), P, t, m)
          Phoenix.PubSub.direct_broadcast!(node(), P, t, m, d)
        end\
      """

      result = Mutare.transform_string(live(body), mutators: [PubSub])
      variants = Enum.map(result.mutants, & &1.variant)

      assert variants ==
               [["subscribe"], ["subscribe"], ["unsubscribe"]] ++
                 List.duplicate(["broadcast"], 16)

      assert Enum.all?(result.mutants, &(&1.mutated_code == ":ok"))
    end
  end

  describe "variant labels (# mutare:ignore[pubsub:<kind>])" do
    test "the declared vocabulary" do
      assert PubSub.variants() == ["subscribe", "unsubscribe", "broadcast"]
    end

    test "a qualified directive suppresses one kind and leaves the others live" do
      body = """
        def go(t) do
          Phoenix.PubSub.subscribe(P, t) # mutare:ignore[pubsub:subscribe]
          Phoenix.PubSub.broadcast(P, t, :m)
        end\
      """

      result = Mutare.transform_string(live(body), mutators: [PubSub])

      assert Enum.map(result.mutants, &{&1.variant, &1.ignored}) ==
               [{["subscribe"], true}, {["broadcast"], false}]
    end
  end

  describe "pipe awareness" do
    test "a piped subscribe is left alone (no faithful pass-through, never idiomatic)" do
      assert pubsub_diffs(live("  def go(p), do: p |> Phoenix.PubSub.subscribe(\"t\")")) == []
    end
  end

  describe "scope" do
    test "leaves other Phoenix.PubSub calls untouched" do
      assert pubsub_diffs(live("  def go, do: Phoenix.PubSub.node_name(P)")) == []
    end

    test "a wrong-arity qualified call is left alone (the arity guard)" do
      one = live("  def go, do: Phoenix.PubSub.subscribe(P)")
      six = live("  def go(m), do: Phoenix.PubSub.broadcast_from(P, self(), \"t\", m, D, :x)")

      assert pubsub_diffs(one) == []
      assert pubsub_diffs(six) == []
    end

    test "does not remove a same-named local subscribe (no import, no qualifier)" do
      source = """
      defmodule L do
        def go, do: subscribe(P, "t")
        def subscribe(_p, _t), do: :ok
      end
      """

      assert pubsub_diffs(source) == []
    end

    test "Phoenix.Channel.broadcast is another module's call (the :channel_message family)" do
      source = live("  def go(s), do: Phoenix.Channel.broadcast(s, \"t\", %{})")

      assert pubsub_diffs(source) == []
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "a qualified subscribe collapses to :ok" do
      assert node_mutations("Phoenix.PubSub.subscribe(P, \"t\")", PubSub) == [":ok"]
    end

    test "a piped stage node yields nothing (piped is left alone)" do
      assert node_mutations("Phoenix.PubSub.subscribe(\"t\")", PubSub, :piped) == []
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule PubSubCompileDemo do
      alias Phoenix.PubSub

      def mount(id) do
        PubSub.subscribe(Demo.PubSub, "room:" <> id)
        :ok
      end

      def announce(id, msg) do
        PubSub.broadcast!(Demo.PubSub, "room:" <> id, {:new, msg})
        PubSub.broadcast_from(Demo.PubSub, self(), "room:" <> id, {:seen, msg})
      end

      # Awkward value positions: the `:ok` must stay compile-safe as a pipe head or a
      # call argument, and as a matched value.
      def awkward(id, m) do
        PubSub.subscribe(Demo.PubSub, id) |> then(&Map.put(m, :result, &1))
        :ok = PubSub.unsubscribe(Demo.PubSub, id)
        Map.put(m, :result, PubSub.local_broadcast(Demo.PubSub, id, :m))
      end
    end
    """

    assert_metamutant_compiles(source, [PubSub])
  end
end
