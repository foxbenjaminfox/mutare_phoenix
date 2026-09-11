defmodule Mutare.Phoenix.ChannelReplyTest do
  @moduledoc """
  `:channel_reply` — drops the reply element of a channel callback return (`{:ok, reply,
  socket}` → `{:ok, socket}`, `{:reply, reply, socket}` → `{:noreply, socket}`, `{:stop,
  reason, reply, socket}` → `{:stop, reason, socket}`), **gated on `@behaviour
  Phoenix.Channel`**. Delivered as the behaviour-aware structural return hook; inert in
  non-channel modules and on shapes with nothing to drop.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Phoenix.ChannelReply

  defp reply_diffs(source), do: diffs_for(source, [ChannelReply], :channel_reply)

  # A channel module via a direct `@behaviour Phoenix.Channel` (no `use` expansion needed).
  defp channel(body),
    do: "defmodule RoomChannel do\n  @behaviour Phoenix.Channel\n\n#{body}\nend\n"

  describe "the reshape table (gated on @behaviour Phoenix.Channel)" do
    test "join {:ok, reply, socket} drops the join reply -> {:ok, socket}" do
      assert reply_diffs(channel("  def join(_t, _p, s), do: {:ok, %{id: 1}, s}")) ==
               [{"{:ok, %{id: 1}, s}", "{:ok, s}"}]
    end

    test "handle_in {:reply, reply, socket} drops the reply -> :noreply" do
      assert reply_diffs(channel("  def handle_in(_e, _p, s), do: {:reply, {:ok, %{}}, s}")) ==
               [{"{:reply, {:ok, %{}}, s}", "{:noreply, s}"}]
    end

    test "a bare-atom reply status is dropped the same way" do
      assert reply_diffs(channel("  def handle_in(_e, _p, s), do: {:reply, :ok, s}")) ==
               [{"{:reply, :ok, s}", "{:noreply, s}"}]
    end

    test "handle_in {:stop, reason, reply, socket} drops the reply, keeps the reason" do
      body = "  def handle_in(_e, _p, s), do: {:stop, :shutdown, {:ok, %{}}, s}"

      assert reply_diffs(channel(body)) ==
               [{"{:stop, :shutdown, {:ok, %{}}, s}", "{:stop, :shutdown, s}"}]
    end

    test "a multi-statement body's reply tail is still reshaped" do
      body = """
        def handle_in(_e, p, s) do
          log(p)
          {:reply, {:ok, p}, s}
        end\
      """

      assert reply_diffs(channel(body)) == [{"{:reply, {:ok, p}, s}", "{:noreply, s}"}]
    end

    test "each branch of a case in tail position is reshaped independently" do
      body = """
        def join(_t, p, s) do
          case p do
            %{"a" => 1} -> {:ok, %{a: 1}, s}
            _ -> {:ok, %{a: 2}, s}
          end
        end\
      """

      assert reply_diffs(channel(body)) == [
               {"{:ok, %{a: 1}, s}", "{:ok, s}"},
               {"{:ok, %{a: 2}, s}", "{:ok, s}"}
             ]
    end
  end

  describe "the use Phoenix.Channel path (use-injected behaviour)" do
    test "a `use Phoenix.Channel` module is gated in too" do
      source = """
      defmodule RoomChannel do
        use Phoenix.Channel
        def handle_in(_e, _p, s), do: {:reply, :ok, s}
      end
      """

      assert reply_diffs(source) == [{"{:reply, :ok, s}", "{:noreply, s}"}]
    end
  end

  describe "scope" do
    test "does NOT fire in a non-channel module" do
      source = """
      defmodule Plain do
        def handle_in(_e, _p, s), do: {:reply, :ok, s}
        def join(_t, _p, s), do: {:ok, %{}, s}
      end
      """

      assert reply_diffs(source) == []
    end

    test "leaves the reply-less returns untouched (nothing to drop)" do
      body = """
        def join(_t, _p, s), do: {:ok, s}
        def handle_in("a", _p, s), do: {:noreply, s}
        def handle_in("b", _p, s), do: {:noreply, s, :hibernate}
        def handle_in("c", _p, s), do: {:stop, :normal, s}
        def handle_out(_e, _p, s), do: {:noreply, s}\
      """

      assert reply_diffs(channel(body)) == []
    end

    test "leaves a join {:error, reason} untouched" do
      assert reply_diffs(channel("  def join(_t, _p, _s), do: {:error, %{reason: \"no\"}}")) ==
               []
    end

    test "leaves a tuple with a computed (non-atom) tag untouched" do
      # The tag is a call, not a literal atom, so `tag_name/1` falls through to nil and no
      # reshape is offered — the tuple is left alone rather than crashing the scan.
      assert reply_diffs(channel("  def handle_in(_e, _p, s), do: {tag(), %{a: 1}, s}")) == []
    end
  end

  describe "not duplicated by the built-in GenServer mutator (different behaviour gate)" do
    test "the GenServer mutator does NOT fire on a channel's {:reply, _, _}" do
      source = channel("  def handle_in(_e, _p, s), do: {:reply, :ok, s}")
      mutators = [ChannelReply, Mutare.Mutators.GenServer]

      assert diffs_for(source, mutators, :genserver) == []

      assert diffs_for(source, mutators, :channel_reply) ==
               [{"{:reply, :ok, s}", "{:noreply, s}"}]
    end
  end

  test "every embedded mutant is a valid channel return that compiles" do
    source = """
    defmodule ChannelReplyCompileDemo do
      use Phoenix.Channel

      def join("room:" <> id, _payload, socket), do: {:ok, %{id: id}, socket}

      def handle_in("ping", payload, socket), do: {:reply, {:ok, payload}, socket}
      def handle_in("bye", _payload, socket), do: {:stop, :normal, :ok, socket}
      def handle_in(_event, _payload, socket), do: {:noreply, socket}
    end
    """

    assert_metamutant_compiles(source, [ChannelReply])
  end
end
