defmodule Demo.Notifications do
  @moduledoc "Subscribe to report updates, publish them, and stop listening."

  def watch(pubsub, report_id) do
    Phoenix.PubSub.subscribe(pubsub, "report:#{report_id}")
  end

  def unwatch(pubsub, report_id) do
    Phoenix.PubSub.unsubscribe(pubsub, "report:#{report_id}")
  end

  def published(pubsub, report_id) do
    Phoenix.PubSub.broadcast(pubsub, "report:#{report_id}", {:published, report_id})
  end
end
