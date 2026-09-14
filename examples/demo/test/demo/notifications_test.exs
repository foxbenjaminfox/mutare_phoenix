defmodule Demo.NotificationsTest do
  use ExUnit.Case

  alias Demo.Notifications

  setup do
    start_supervised!({Registry, keys: :duplicate, name: Demo.PubSub})
    :ok
  end

  test "watching a report succeeds" do
    assert Notifications.watch(Demo.PubSub, 7) == :ok
  end

  test "unwatching a report succeeds" do
    Phoenix.PubSub.subscribe(Demo.PubSub, "report:7")
    assert Notifications.unwatch(Demo.PubSub, 7) == :ok
  end

  test "publishing a report succeeds" do
    assert Notifications.published(Demo.PubSub, 7) == :ok
  end
end
