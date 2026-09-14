defmodule Demo.RoomChannel do
  @moduledoc "A room with join metadata, callback replies, and outbound messages."
  @behaviour Phoenix.Channel

  @impl true
  def join("room:" <> id, _payload, socket) do
    {:ok, %{room_id: id}, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("leave", _payload, socket) do
    {:stop, :normal, {:ok, %{left: true}}, socket}
  end

  def handle_in("message", payload, socket) do
    Phoenix.Channel.broadcast(socket, "message", payload)
    {:noreply, socket}
  end

  def handle_in("presence", _payload, socket) do
    Phoenix.Channel.push(socket, "presence", %{online: 1})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:receipt_ready, ref, id}, socket) do
    Phoenix.Channel.reply(ref, {:ok, %{receipt_id: id}})
    {:noreply, socket}
  end
end
