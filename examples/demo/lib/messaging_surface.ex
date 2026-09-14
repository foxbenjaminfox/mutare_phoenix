# Executable stand-ins for the demo, outside the mutation target `lib/demo`.
# These deliver actual BEAM messages, but do not implement Phoenix transports.
defmodule Phoenix.Channel do
  @moduledoc "Minimal channel callbacks and observable outbound messages."

  @callback join(binary(), map(), map()) :: tuple()
  @callback handle_in(binary(), map(), map()) :: tuple()
  @callback handle_info(term(), map()) :: tuple()

  def broadcast(socket, event, payload) do
    send(socket.transport_pid, {:broadcast, socket.topic, event, payload})
    :ok
  end

  def push(socket, event, payload) do
    send(socket.transport_pid, {:push, event, payload})
    :ok
  end

  def reply({pid, ref}, payload) do
    send(pid, {:reply, ref, payload})
    :ok
  end
end

defmodule Phoenix.PubSub do
  @moduledoc "A local PubSub stand-in backed by a supervised duplicate-key Registry."

  def subscribe(pubsub, topic) do
    {:ok, _owner} = Registry.register(pubsub, topic, nil)
    :ok
  end

  def unsubscribe(pubsub, topic), do: Registry.unregister(pubsub, topic)

  def broadcast(pubsub, topic, message) do
    Registry.dispatch(pubsub, topic, fn entries ->
      for {pid, _value} <- entries, do: send(pid, message)
    end)
  end
end
