defmodule Bnana.PhoenixClient do
  @moduledoc "Owns Bnana's authenticated Phoenix socket and fans updates out to Mob screens."

  use GenServer

  alias Phoenix.SocketClient.Channel
  alias Phoenix.SocketClient.ChannelManager

  @default_url "wss://phoenix.aayushsahu.com/tui/websocket"
  @topic "events"
  @request_timeout 10_000
  @health_interval 1_000
  @connection_timeout 15_000

  defstruct socket: nil,
            socket_monitor: nil,
            channel: nil,
            secret: nil,
            status: :needs_secret,
            error: nil,
            subscribers: %{},
            foreground?: true,
            connecting_since: nil,
            persisted?: false

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def subscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  def unsubscribe(pid \\ self()) do
    GenServer.cast(__MODULE__, {:unsubscribe, pid})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def configure_secret(secret) when is_binary(secret) do
    GenServer.call(__MODULE__, {:configure_secret, String.trim(secret)}, 15_000)
  end

  def disconnect do
    GenServer.call(__MODULE__, :disconnect)
  end

  def reconnect do
    GenServer.call(__MODULE__, :reconnect)
  end

  def request(event, action, data \\ nil, recipient \\ self())
      when is_binary(event) and is_binary(action) and is_pid(recipient) do
    ref = make_ref()

    Task.start(fn ->
      payload = request_payload(action, data)
      result = perform_request(event, payload)
      send(recipient, {:phoenix_reply, ref, event, action, result})
    end)

    ref
  end

  defp perform_request(event, payload) do
    with {:ok, channel} <- GenServer.call(__MODULE__, :channel),
         {:ok, response} <- safe_push(channel, event, payload) do
      unwrap_response(response)
    end
  end

  defp safe_push(channel, event, payload) do
    Channel.push(channel, event, payload, @request_timeout)
  catch
    :exit, reason -> {:error, normalize_exit(reason)}
  end

  defp unwrap_response(%{"payload" => %{"data" => data}}), do: {:ok, data}
  defp unwrap_response(%{payload: %{data: data}}), do: {:ok, data}
  defp unwrap_response(response), do: {:ok, response}

  defp request_payload(action, nil), do: %{"action" => action}
  defp request_payload(action, data), do: %{"action" => action, "data" => data}

  defp normalize_exit({reason, _details}), do: reason
  defp normalize_exit(reason), do: reason

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    maybe_subscribe_to_device()

    {secret, persisted?} = configured_secret()
    foreground? = device_foreground?()

    state = %__MODULE__{
      secret: secret,
      status: initial_status(secret, foreground?),
      foreground?: foreground?,
      persisted?: persisted?
    }

    resolve_phoenix_host()
    send(self(), :ensure_connection)
    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    monitor = Process.monitor(pid)
    send(pid, {:phoenix_status, public_status(state)})
    {:reply, :ok, %{state | subscribers: Map.put(state.subscribers, pid, monitor)}}
  end

  def handle_call(:status, _from, state) do
    {:reply, public_status(state), state}
  end

  def handle_call(:channel, _from, %{status: :connected, channel: channel} = state)
      when is_pid(channel) do
    if Process.alive?(channel) do
      {:reply, {:ok, channel}, state}
    else
      {:reply, {:error, :not_connected}, %{state | channel: nil, status: :connecting}}
    end
  end

  def handle_call(:channel, _from, state), do: {:reply, {:error, :not_connected}, state}

  def handle_call({:configure_secret, ""}, _from, state) do
    state = state |> stop_socket() |> set_status(:needs_secret, "A secret is required")
    {:reply, {:error, :empty_secret}, state}
  end

  def handle_call({:configure_secret, secret}, _from, state) do
    state = %{stop_socket(state) | secret: secret, error: nil, persisted?: false}
    state = if state.foreground?, do: start_socket(state), else: set_status(state, :suspended)
    {:reply, :ok, state}
  end

  def handle_call(:disconnect, _from, state) do
    _ = Bnana.CredentialStore.delete()

    state =
      state
      |> stop_socket()
      |> Map.merge(%{secret: nil, persisted?: false})
      |> set_status(:needs_secret)

    {:reply, :ok, state}
  end

  def handle_call(:reconnect, _from, state) do
    state = stop_socket(state)
    state = if state.foreground?, do: start_socket(state), else: set_status(state, :suspended)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:unsubscribe, pid}, state) do
    {:noreply, drop_subscriber(state, pid)}
  end

  @impl true
  def handle_info(:ensure_connection, state) do
    state =
      cond do
        is_nil(state.secret) -> set_status(state, :needs_secret)
        not state.foreground? -> set_status(state, :suspended)
        socket_alive?(state) -> state
        true -> start_socket(state)
      end

    schedule_health_check()
    {:noreply, state}
  end

  def handle_info(:health_check, state) do
    state = refresh_connection(state)
    schedule_health_check()
    {:noreply, state}
  end

  def handle_info({:phoenix_channel_event, event, payload}, state) do
    broadcast(state, {:phoenix_event, event, payload})
    {:noreply, state}
  end

  def handle_info({:phoenix_channel_closed, reason}, state) do
    state = %{state | channel: nil}
    {:noreply, set_status(state, :connecting, inspect(reason))}
  end

  def handle_info({:mob_device, :did_enter_background}, state) do
    state = %{stop_socket(state) | foreground?: false}
    {:noreply, set_status(state, :suspended)}
  end

  def handle_info({:mob_device, event}, state)
      when event in [:will_enter_foreground, :did_become_active] do
    if event == :did_become_active, do: Bnana.DeepLinks.consume()
    state = %{state | foreground?: true}
    send(self(), :ensure_connection)
    {:noreply, state}
  end

  def handle_info({:mob_device, :connectivity_changed, %{online: true}}, state) do
    send(self(), :ensure_connection)
    {:noreply, state}
  end

  def handle_info({:mob_device, :connectivity_changed, %{online: false}}, state) do
    {:noreply, set_status(state, :offline)}
  end

  def handle_info({:DOWN, monitor, :process, pid, _reason}, state) do
    cond do
      monitor == state.socket_monitor ->
        state = %{state | socket: nil, socket_monitor: nil, channel: nil}
        send(self(), :ensure_connection)
        {:noreply, set_status(state, :connecting)}

      Map.get(state.subscribers, pid) == monitor ->
        {:noreply, drop_subscriber(state, pid)}

      true ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, _pid, _reason}, state), do: {:noreply, state}
  def handle_info(_message, state), do: {:noreply, state}

  defp start_socket(%{secret: nil} = state), do: set_status(state, :needs_secret)

  defp start_socket(state) do
    resolve_phoenix_host()

    options = [
      name: Bnana.PhoenixSocket,
      url: phoenix_url(),
      params: %{"secret" => state.secret},
      json_library: JSON,
      reconnect?: true,
      reconnect_interval: 2_000,
      join_channels: [@topic],
      topic_channel_map: %{@topic => Bnana.PhoenixChannel}
    ]

    case Phoenix.SocketClient.start_link(options) do
      {:ok, socket} ->
        Process.unlink(socket)
        monitor = Process.monitor(socket)

        state
        |> Map.merge(%{
          socket: socket,
          socket_monitor: monitor,
          channel: nil,
          connecting_since: now_ms()
        })
        |> set_status(:connecting)

      {:error, {:already_started, socket}} ->
        %{
          state
          | socket: socket,
            socket_monitor: Process.monitor(socket),
            connecting_since: now_ms()
        }
        |> set_status(:connecting)

      {:error, reason} ->
        set_status(state, :error, inspect(reason))
    end
  end

  defp stop_socket(%{socket: socket} = state) when is_pid(socket) do
    if Process.alive?(socket), do: Supervisor.stop(socket, :normal, 5_000)
    if state.socket_monitor, do: Process.demonitor(state.socket_monitor, [:flush])
    %{state | socket: nil, socket_monitor: nil, channel: nil, connecting_since: nil}
  catch
    :exit, _ ->
      %{state | socket: nil, socket_monitor: nil, channel: nil, connecting_since: nil}
  end

  defp stop_socket(state),
    do: %{state | socket: nil, socket_monitor: nil, channel: nil, connecting_since: nil}

  defp refresh_connection(%{socket: socket} = state) when is_pid(socket) do
    cond do
      not Process.alive?(socket) ->
        send(self(), :ensure_connection)
        set_status(%{state | socket: nil, channel: nil}, :connecting)

      Phoenix.SocketClient.connected?(socket) ->
        connected_channel(state)

      connection_timed_out?(state) ->
        set_status(state, :error, "Could not connect. Check the secret and network.")

      state.foreground? ->
        set_status(%{state | channel: nil}, :connecting)

      true ->
        set_status(state, :suspended)
    end
  end

  defp refresh_connection(%{secret: secret, foreground?: true} = state) when is_binary(secret) do
    start_socket(state)
  end

  defp refresh_connection(state), do: state

  defp connected_channel(state) do
    channel = ChannelManager.channel_pid(state.socket, @topic)

    if is_pid(channel) and Process.alive?(channel),
      do: connected(state, channel),
      else: set_status(state, :connecting)
  end

  defp socket_alive?(%{socket: socket}) when is_pid(socket), do: Process.alive?(socket)
  defp socket_alive?(_state), do: false

  defp connected(state, channel) do
    persisted? = persist_secret(state)

    %{state | channel: channel, connecting_since: nil, persisted?: persisted?}
    |> set_status(:connected)
  end

  defp persist_secret(%{persisted?: true}), do: true

  defp persist_secret(%{secret: secret}) when is_binary(secret) do
    Bnana.CredentialStore.save(secret) == :ok
  end

  defp persist_secret(_state), do: false

  defp connection_timed_out?(%{connecting_since: nil}), do: false

  defp connection_timed_out?(%{connecting_since: started_at}) do
    now_ms() - started_at >= @connection_timeout
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp set_status(state, status, error \\ nil) do
    updated = %{state | status: status, error: error}

    if state.status != updated.status or state.error != updated.error do
      broadcast(updated, {:phoenix_status, public_status(updated)})
    end

    updated
  end

  defp public_status(state) do
    %{
      status: state.status,
      error: state.error,
      configured?: is_binary(state.secret),
      persisted?: state.persisted?,
      url: phoenix_url()
    }
  end

  defp broadcast(state, message) do
    Enum.each(state.subscribers, fn {pid, _monitor} -> send(pid, message) end)
  end

  defp drop_subscriber(state, pid) do
    case Map.pop(state.subscribers, pid) do
      {nil, subscribers} ->
        %{state | subscribers: subscribers}

      {monitor, subscribers} ->
        Process.demonitor(monitor, [:flush])
        %{state | subscribers: subscribers}
    end
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_interval)
  end

  defp configured_secret do
    case System.get_env("MEOWUI_SECRET") do
      secret when is_binary(secret) and byte_size(secret) > 0 ->
        {String.trim(secret), false}

      _ ->
        case Application.get_env(:bnana, :phoenix_secret) do
          secret when is_binary(secret) and byte_size(secret) > 0 -> {String.trim(secret), false}
          _ -> stored_secret()
        end
    end
  end

  defp stored_secret do
    case Bnana.CredentialStore.load() do
      {:ok, secret} -> {secret, true}
      :not_found -> {nil, false}
    end
  end

  defp phoenix_url do
    System.get_env("PHOENIX_WS_URL") || Application.get_env(:bnana, :phoenix_url, @default_url)
  end

  # Resolve the Phoenix host through Apple's native resolver and seed
  # :inet_db, because the pure-Beam :dns path (Google/Cloudflare fallbacks
  # from Mob.DNS.configure_pure_beam/1) is commonly blocked on device
  # networks and fails with :nxdomain. Resolve/1 is idempotent and safe to
  # call on the host (returns {:error, :nif_not_loaded} there).
  defp resolve_phoenix_host do
    uri = URI.parse(phoenix_url())
    if uri.host, do: Mob.DNS.resolve(uri.host)
  end

  defp initial_status(nil, _foreground?), do: :needs_secret
  defp initial_status(_secret, false), do: :suspended
  defp initial_status(_secret, true), do: :connecting

  defp maybe_subscribe_to_device do
    if Process.whereis(Mob.Device), do: Mob.Device.subscribe([:app, :network])
  end

  defp device_foreground? do
    if Process.whereis(Mob.Device), do: Mob.Device.foreground?(), else: true
  rescue
    _ -> true
  end
end
