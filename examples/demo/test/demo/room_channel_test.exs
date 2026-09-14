defmodule Demo.RoomChannelTest do
  use ExUnit.Case, async: true

  alias Demo.RoomChannel

  setup do
    %{socket: %{topic: "room:lobby", transport_pid: self()}}
  end

  test "joining succeeds", %{socket: socket} do
    # Both {:ok, reply, socket} and {:ok, socket} count as success.
    assert elem(RoomChannel.join("room:lobby", %{}, socket), 0) == :ok
  end

  test "ping replies with its payload", %{socket: socket} do
    # This reply is asserted, so dropping it is killed.
    assert RoomChannel.handle_in("ping", %{id: 7}, socket) ==
             {:reply, {:ok, %{id: 7}}, socket}
  end

  test "leaving stops the channel", %{socket: socket} do
    assert elem(RoomChannel.handle_in("leave", %{}, socket), 0) == :stop
  end

  test "posting a message keeps the channel running", %{socket: socket} do
    assert RoomChannel.handle_in("message", %{body: "hello"}, socket) == {:noreply, socket}
  end

  test "requesting presence keeps the channel running", %{socket: socket} do
    assert RoomChannel.handle_in("presence", %{}, socket) == {:noreply, socket}
  end

  test "a completed receipt keeps the channel running", %{socket: socket} do
    ref = {self(), make_ref()}
    assert RoomChannel.handle_info({:receipt_ready, ref, 7}, socket) == {:noreply, socket}
  end
end
