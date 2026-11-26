defmodule ContractController do
  use Phoenix.Controller, formats: []

  def ping(conn, _params), do: text(conn, "pong")

  def export(conn, _params) do
    send_download(conn, {:binary, "a,b"}, filename: "report.csv", disposition: :attachment)
  end

  def login(conn, _params) do
    conn
    |> Plug.Conn.put_status(:found)
    |> redirect(to: "/login")
  end
end

defmodule ContractChannel do
  use Phoenix.Channel

  def join("room:lobby", _payload, socket), do: {:ok, %{room: "lobby"}, socket}

  def handle_in("count", _payload, socket) do
    push(socket, "count", %{value: 1})
    {:noreply, socket}
  end
end

defmodule ContractNotifications do
  def announce(pubsub, topic), do: Phoenix.PubSub.broadcast(pubsub, topic, :notice)
end

defmodule ContractTokens do
  def sign(secret, data), do: Phoenix.Token.sign(secret, "contract", data)
  def verify(secret, token), do: Phoenix.Token.verify(secret, "contract", token, max_age: 60)
end
