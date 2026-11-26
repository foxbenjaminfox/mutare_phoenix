defmodule MutarePhoenixIntegration.PhoenixContractTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  @token_context String.duplicate("fixture secret ", 8)

  setup_all do
    families = Mutare.Phoenix.all() ++ [Mutare.Plug.Status]

    {[controller, channel, notifications, tokens], sites} =
      compile_fixture("surface.ex", families)

    %{
      controller: controller,
      channel: channel,
      notifications: notifications,
      tokens: tokens,
      sites: sites
    }
  end

  test "blanking a controller body keeps the response status", %{
    controller: controller,
    sites: sites
  } do
    ping = fn ->
      response = controller.ping(Plug.Test.conn(:get, "/ping"), %{})
      {response.status, response.resp_body}
    end

    assert {{200, "pong"}, {200, ""}} =
             observe_mutant(sites, {~r/^text\(conn, "pong"\)/, ~r/^text\(conn, ""\)/}, ping)
  end

  test "flipping a download disposition changes the content-disposition header", %{
    controller: controller,
    sites: sites
  } do
    export = fn ->
      response = controller.export(Plug.Test.conn(:get, "/export"), %{})
      Plug.Conn.get_resp_header(response, "content-disposition")
    end

    assert {[~s(attachment; filename="report.csv")], [~s(inline; filename="report.csv")]} =
             observe_mutant(
               sites,
               {~r/disposition: :attachment/, ~r/disposition: :inline/},
               export
             )
  end

  test "Plug status mutations change the redirect status and preserve the location", %{
    controller: controller,
    sites: sites
  } do
    login = fn ->
      response = controller.login(Plug.Test.conn(:get, "/"), %{})
      {response.status, Plug.Conn.get_resp_header(response, "location")}
    end

    assert {{302, ["/login"]}, {303, ["/login"]}} =
             observe_mutant(
               sites,
               {~r/put_status\(:found\)/, ~r/put_status\(:see_other\)/},
               login
             )
  end

  test "dropping the join reply preserves the successful join", %{channel: channel, sites: sites} do
    socket = %Phoenix.Socket{topic: "room:lobby"}
    join = fn -> channel.join(socket.topic, %{}, socket) end

    assert {{:ok, %{room: "lobby"}, ^socket}, {:ok, ^socket}} =
             observe_mutant(sites, {~s({:ok, %{room: "lobby"}, socket}), "{:ok, socket}"}, join)
  end

  test "removing a channel push keeps the callback return and suppresses delivery", %{
    channel: channel,
    sites: sites
  } do
    socket = %Phoenix.Socket{
      topic: "room:lobby",
      joined: true,
      transport_pid: self(),
      serializer: Phoenix.ChannelTest.NoopSerializer
    }

    request = fn ->
      assert {:noreply, ^socket} = channel.handle_in("count", %{}, socket)

      receive do
        %Phoenix.Socket.Message{} = message -> message
      after
        0 -> :no_push
      end
    end

    assert {%Phoenix.Socket.Message{event: "count", payload: %{value: 1}}, :no_push} =
             observe_mutant(sites, {~r/^push\(socket, "count"/, ":ok"}, request)
  end

  test "removing a PubSub broadcast keeps the success return and suppresses delivery", %{
    notifications: notifications,
    sites: sites
  } do
    pubsub = MutarePhoenixIntegration.PubSub
    start_supervised!({Phoenix.PubSub, name: pubsub})
    :ok = Phoenix.PubSub.subscribe(pubsub, "reports")

    announce = fn ->
      assert :ok = notifications.announce(pubsub, "reports")

      receive do
        :notice -> :notice
      after
        0 -> :no_notice
      end
    end

    assert {:notice, :no_notice} =
             observe_mutant(
               sites,
               {"Phoenix.PubSub.broadcast(pubsub, topic, :notice)", ":ok"},
               announce
             )
  end

  test "token mutations change the result of a Phoenix.Token round-trip", %{
    tokens: tokens,
    sites: sites
  } do
    round_trip = fn ->
      token = tokens.sign(@token_context, 42)
      tokens.verify(@token_context, token)
    end

    assert {{:ok, 42}, {:ok, nil}} =
             observe_mutant(
               sites,
               {~r/^Phoenix.Token.sign/, ~r/^Phoenix.Token.sign.*nil\)/},
               round_trip
             )

    assert {{:ok, 42}, {:error, :invalid}} =
             observe_mutant(
               sites,
               {~r/^Phoenix.Token.sign/, ~r/^Phoenix.Token.encrypt/},
               round_trip
             )
  end

  test "disabling token expiry accepts a token signed in the past", %{
    tokens: tokens,
    sites: sites
  } do
    expired = Phoenix.Token.sign(@token_context, "contract", 42, signed_at: 1_000_000_000)
    verify = fn -> tokens.verify(@token_context, expired) end

    assert {{:error, :expired}, {:ok, 42}} =
             observe_mutant(sites, {~r/max_age: 60/, ~r/max_age: :infinity/}, verify)
  end

  test "the extension keeps Phoenix router and HEEx macros compilable with built-ins enabled" do
    {[controller, router, component], sites} =
      compile_fixture("macros.ex", [:builtins])

    assert %{plug: ^controller, plug_opts: :ping} =
             Phoenix.Router.route_info(router, "GET", "/api/ping", "example.com")

    render = fn -> component.render(%{name: "Ada"}) end
    assert {rendered, nil} = observe_mutant(sites, {~r/^~H/, "nil"}, render)
    assert Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary() =~ "<p>Ada</p>"
  end

  defp compile_fixture(name, mutators) do
    path = Path.expand("../fixtures/#{name}", __DIR__)
    compile_metamutant(File.read!(path), mutators, file: path, extensions: [Mutare.Phoenix])
  end
end
