defmodule Bnana.PhoenixChannel do
  @moduledoc false

  use Phoenix.SocketClient.Channel

  @impl true
  def handle_message(event, payload, state) do
    if client = Process.whereis(Bnana.PhoenixClient) do
      send(client, {:phoenix_channel_event, event, payload})
    end

    {:noreply, state}
  end

  @impl true
  def handle_close(reason, state) do
    if client = Process.whereis(Bnana.PhoenixClient) do
      send(client, {:phoenix_channel_closed, reason})
    end

    {:noreply, state}
  end
end
