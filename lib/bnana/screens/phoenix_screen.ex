defmodule Bnana.PhoenixScreen do
  @moduledoc "Entry point for Phoenix-backed tools."

  use Mob.Screen

  alias Bnana.{PhoenixClient, RemoteUI}

  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    PhoenixClient.subscribe()

    {:ok,
     socket
     |> Mob.Socket.assign(:connection, PhoenixClient.status())
     |> Mob.Socket.assign(:secret, "")}
  end

  def render(assigns) do
    content = content(assigns)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Phoenix")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="phoenix_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {RemoteUI.intro("A window into the site.", "Live data and small tools, carried by a Phoenix Channel.")}
            <Spacer size={18} />
            {RemoteUI.status_pill(assigns.connection)}
            <Spacer size={24} />
            {content}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket) do
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  def handle_info({:change, :phoenix_secret, value}, socket) do
    {:noreply, Mob.Socket.assign(socket, :secret, value)}
  end

  def handle_info({:tap, :connect}, socket) do
    case PhoenixClient.configure_secret(socket.assigns.secret) do
      :ok -> {:noreply, Mob.Socket.assign(socket, :secret, "")}
      {:error, _} -> {:noreply, Mob.Alert.toast(socket, "Enter the Phoenix secret")}
    end
  end

  def handle_info({:tap, :disconnect}, socket) do
    :ok = PhoenixClient.disconnect()
    {:noreply, socket}
  end

  def handle_info({:tap, :reconnect}, socket) do
    :ok = PhoenixClient.reconnect()
    {:noreply, socket}
  end

  def handle_info({:tap, :open_analytics}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.AnalyticsScreen)}
  end

  def handle_info({:tap, :open_bin}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.BinScreen)}
  end

  def handle_info({:tap, :open_notes}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.WorkspacesScreen)}
  end

  def handle_info({:tap, :open_comments}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.CommentsScreen)}
  end

  def handle_info({:tap, :open_contact}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.ContactMessagesScreen)}
  end

  def handle_info({:phoenix_status, connection}, socket) do
    {:noreply, Mob.Socket.assign(socket, :connection, connection)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def terminate(_reason, _socket) do
    PhoenixClient.unsubscribe()
    :ok
  end

  defp content(%{connection: %{status: :connected}}) do
    items = [
      RemoteUI.menu_button(
        "Analytics",
        "Stats, daily movement and visitor devices.",
        :open_analytics
      ),
      ~MOB(<Spacer size={12} />),
      RemoteUI.menu_button("Bin", "Read and tend to pastes from the road.", :open_bin),
      ~MOB(<Spacer size={12} />),
      RemoteUI.menu_button("Notes", "Browse workspaces and keep notes close.", :open_notes),
      ~MOB(<Spacer size={12} />),
      RemoteUI.menu_button("Comments", "Review conversations across the blog.", :open_comments),
      ~MOB(<Spacer size={12} />),
      RemoteUI.menu_button("Contact", "Read messages sent through the site.", :open_contact),
      ~MOB(<Spacer size={20} />),
      disconnect_button()
    ]

    ~MOB(<Column fill_width={true}>
  {items}
</Column>)
  end

  defp content(%{connection: %{status: :error, configured?: true}}) do
    font = @ui_font
    retry_tap = {self(), :reconnect}
    forget_tap = {self(), :disconnect}

    ~MOB"""
    <Box
      background={:surface}
      border_color={:error}
      border_width={1}
      corner_radius={:radius_lg}
      padding={:space_lg}
      fill_width={true}
    >
      <Column fill_width={true}>
        <Text
          text="The saved session could not connect."
          text_size={:base}
          font={font}
          text_color={:on_surface}
        />
        <Text
          text="Try again, or forget it and enter a replacement."
          text_size={:sm}
          text_color={:muted}
          padding_top={:space_xs}
        />
        <Spacer size={14} />
        <Button
          text="Try again"
          font={font}
          background={:primary}
          text_color={:on_primary}
          on_tap={retry_tap}
        />
        <Spacer size={8} />
        <Button
          text="Forget saved session"
          font={font}
          background={:surface_raised}
          text_color={:error}
          on_tap={forget_tap}
        />
      </Column>
    </Box>
    """
  end

  defp content(%{connection: %{configured?: true}}), do: RemoteUI.loading("Opening the channel…")

  defp content(_assigns) do
    font = @ui_font
    change = {self(), :phoenix_secret}
    tap = {self(), :connect}

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_lg}
      padding={:space_lg}
      fill_width={true}
    >
      <Column fill_width={true}>
        <Text text="Connect this device" text_size={:lg} text_color={:on_surface} font={font} />
        <Text
          text="Enter it once. After Phoenix accepts it, the session is saved in this app's private storage and restored automatically."
          text_size={:sm}
          text_color={:muted}
          line_height={1.4}
          padding_top={:space_xs}
        />
        <Spacer size={16} />
        <TextField
          id="phoenix_secret"
          placeholder="Phoenix secret"
          value=""
          secure={true}
          return_key="done"
          on_change={change}
        />
        <Spacer size={12} />
        <Button
          text="Connect"
          font={font}
          background={:primary}
          text_color={:on_primary}
          on_tap={tap}
        />
      </Column>
    </Box>
    """
  end

  defp disconnect_button do
    font = @ui_font
    tap = {self(), :disconnect}

    ~MOB(<Button
  text="Forget saved session & disconnect"
  font={font}
  background={:surface}
  text_color={:error}
  on_tap={tap}
/>)
  end
end
