defmodule Mutare.Phoenix.ChannelMessageTest do
  @moduledoc """
  `:channel_message` — three variant-labelled removals on the `Phoenix.Channel` outbound
  calls, each collapsing the call to the `:ok` its happy path returns: `broadcast` (the four
  `broadcast`/`broadcast!`/`broadcast_from`/`broadcast_from!` forms), `push`, and `reply`.
  Matches direct, aliased, and bare-imported (`use Phoenix.Channel`) forms; the
  never-idiomatic piped form is left alone.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Phoenix.ChannelMessage

  defp message_diffs(source), do: diffs_for(source, [ChannelMessage], :channel_message)

  defp channel(body), do: "defmodule RoomChannel do\n  use Phoenix.Channel\n\n#{body}\nend\n"

  describe "removal across written forms" do
    test "a qualified Phoenix.Channel.broadcast collapses to :ok" do
      source =
        "defmodule C do\n  def go(s), do: Phoenix.Channel.broadcast(s, \"new_msg\", %{})\nend\n"

      assert message_diffs(source) == [{"Phoenix.Channel.broadcast(s, \"new_msg\", %{})", ":ok"}]
    end

    test "a bare imported broadcast! (use-style) collapses to :ok" do
      assert message_diffs(channel("  def go(s), do: broadcast!(s, \"new_msg\", %{a: 1})")) ==
               [{"broadcast!(s, \"new_msg\", %{a: 1})", ":ok"}]
    end

    test "an aliased Ch.push collapses to :ok" do
      source = """
      defmodule C do
        alias Phoenix.Channel, as: Ch
        def go(s), do: Ch.push(s, "state", %{})
      end
      """

      assert message_diffs(source) == [{"Ch.push(s, \"state\", %{})", ":ok"}]
    end

    test "every outbound call fires, tagged with its kind" do
      body = """
        def go(s, ref) do
          broadcast(s, "a", %{})
          broadcast!(s, "b", %{})
          broadcast_from(s, "c", %{})
          broadcast_from!(s, "d", %{})
          push(s, "e", %{})
          reply(ref, {:ok, %{}})
        end\
      """

      result = Mutare.transform_string(channel(body), mutators: [ChannelMessage])

      assert Enum.map(result.mutants, &{&1.original_code, &1.variant}) == [
               {"broadcast(s, \"a\", %{})", ["broadcast"]},
               {"broadcast!(s, \"b\", %{})", ["broadcast"]},
               {"broadcast_from(s, \"c\", %{})", ["broadcast"]},
               {"broadcast_from!(s, \"d\", %{})", ["broadcast"]},
               {"push(s, \"e\", %{})", ["push"]},
               {"reply(ref, {:ok, %{}})", ["reply"]}
             ]

      assert Enum.all?(result.mutants, &(&1.mutated_code == ":ok"))
    end
  end

  describe "variant labels (# mutare:ignore[channel_message:<kind>])" do
    test "the declared vocabulary" do
      assert ChannelMessage.variants() == ["broadcast", "push", "reply"]
    end

    test "a qualified directive suppresses one kind and leaves the others live" do
      body = """
        def go(s) do
          broadcast(s, "a", %{})
          push(s, "b", %{}) # mutare:ignore[channel_message:push]
        end\
      """

      result = Mutare.transform_string(channel(body), mutators: [ChannelMessage])

      assert Enum.map(result.mutants, &{&1.variant, &1.ignored}) ==
               [{["broadcast"], false}, {["push"], true}]
    end
  end

  describe "pipe awareness" do
    test "a piped broadcast is left alone (no faithful pass-through, never idiomatic)" do
      assert message_diffs(channel("  def go(s), do: s |> broadcast(\"a\", %{})")) == []
    end
  end

  describe "scope" do
    test "leaves other Phoenix.Channel calls untouched" do
      assert message_diffs(channel("  def go(s), do: socket_ref(s)")) == []
    end

    test "a wrong-arity qualified call is left alone (the arity guard)" do
      two = "defmodule C do\n  def go(s), do: Phoenix.Channel.broadcast(s, \"a\")\nend\n"
      three = "defmodule C do\n  def go(r), do: Phoenix.Channel.reply(r, :ok, %{})\nend\n"

      assert message_diffs(two) == []
      assert message_diffs(three) == []
    end

    test "does not remove a same-named local push (no import, no qualifier)" do
      source = """
      defmodule C do
        def go(s), do: push(s, "a", %{})
        def push(_s, _e, _m), do: :ok
      end
      """

      assert message_diffs(source) == []
    end

    test "Phoenix.PubSub.broadcast is another module's call (the :pubsub family)" do
      source = "defmodule C do\n  def go, do: Phoenix.PubSub.broadcast(P, \"t\", :m)\nend\n"

      assert message_diffs(source) == []
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "a qualified broadcast collapses to :ok" do
      assert node_mutations("Phoenix.Channel.broadcast(s, \"a\", %{})", ChannelMessage) ==
               [":ok"]
    end

    test "a piped stage node yields nothing (piped is left alone)" do
      assert node_mutations("Phoenix.Channel.broadcast(\"a\", %{})", ChannelMessage, :piped) ==
               []
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule ChannelMessageCompileDemo do
      use Phoenix.Channel

      def handle_in("new_msg", %{"body" => body}, socket) do
        broadcast!(socket, "new_msg", %{body: body})
        broadcast_from(socket, "typing", %{})
        push(socket, "ack", %{})
        {:noreply, socket}
      end

      def handle_in("slow", _payload, socket) do
        ref = socket_ref(socket)
        reply(ref, {:ok, %{}})
        {:noreply, socket}
      end

      # Awkward value positions: the `:ok` must stay compile-safe as a pipe head or a
      # call argument.
      def awkward(socket, m) do
        broadcast(socket, "a", %{}) |> then(&Map.put(m, :result, &1))
        Map.put(m, :result, push(socket, "b", %{}))
      end
    end
    """

    assert_metamutant_compiles(source, [ChannelMessage])
  end
end
