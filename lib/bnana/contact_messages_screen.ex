defmodule Bnana.ContactMessagesScreen do
  @moduledoc "Read-only native contact inbox."

  use Mob.Screen

  alias Bnana.{PhoenixClient, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    PhoenixClient.subscribe()
    load_messages()
    {:ok, socket |> Mob.Socket.assign(:messages, nil) |> Mob.Socket.assign(:error, nil)}
  end

  def render(assigns) do
    content = message_content(assigns)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Contact")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="contact_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {RemoteUI.intro("Messages that found you.", "A read-only view of the contact inbox—nothing here changes the originals.")}
            <Spacer size={22} />
            {content}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, {:open_message, id}}, socket) do
    case Enum.find(socket.assigns.messages || [], &(&1["id"] == id)) do
      nil ->
        {:noreply, socket}

      message ->
        {:noreply, Mob.Socket.push_screen(socket, Bnana.ContactMessageScreen, %{record: message})}
    end
  end

  def handle_info({:phoenix_reply, _ref, "contact-messages", "get-all", {:ok, messages}}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:messages, messages) |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:phoenix_reply, _ref, "contact-messages", "get-all", {:error, reason}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :error, "Could not load messages: #{inspect(reason)}")}
  end

  def handle_info({:phoenix_status, %{status: :connected}}, socket) do
    load_messages()
    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def terminate(_reason, _socket) do
    PhoenixClient.unsubscribe()
    :ok
  end

  defp load_messages, do: PhoenixClient.request("contact-messages", "get-all")

  defp message_content(%{messages: nil, error: nil}), do: RemoteUI.loading("Opening messages…")
  defp message_content(%{error: error}) when is_binary(error), do: RemoteUI.error(error)

  defp message_content(%{messages: []}) do
    font = @display_font
    ~MOB(<Text
  text="No messages yet."
  text_size={:lg}
  font={font}
  text_color={:muted}
  text_align="center"
/>)
  end

  defp message_content(%{messages: messages}) do
    cards =
      messages
      |> Enum.map(&message_card/1)
      |> Enum.intersperse(~MOB(<Spacer size={10} />))

    ~MOB(<Column fill_width={true}>
  {cards}
</Column>)
  end

  defp message_card(message) do
    email = message["email"] || "Unknown sender"
    excerpt = (message["message"] || "") |> String.slice(0, 140)
    timestamp = RemoteUI.short_time(message["inserted_at"])
    tap = {self(), {:open_message, message["id"]}}
    display_font = @display_font
    ui_font = @ui_font

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_md}
      fill_width={true}
      on_tap={tap}
    >
      <Column fill_width={true}>
        <Row fill_width={true}>
          <Text
            text={email}
            text_size={:base}
            font={display_font}
            font_weight="bold"
            text_color={:on_surface}
          />
          <Spacer />
          <Text text="→" text_size={:base} text_color={:primary} />
        </Row>
        <Text
          text={timestamp}
          text_size={:xs}
          font={ui_font}
          text_color={:secondary}
          padding_top={:space_xs}
        />
        <Text
          text={excerpt}
          text_size={:sm}
          font={display_font}
          text_color={:muted}
          line_height={1.35}
          padding_top={:space_xs}
        />
      </Column>
    </Box>
    """
  end
end

defmodule Bnana.ContactMessageScreen do
  @moduledoc false

  use Mob.Screen

  alias Bnana.RemoteUI

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(params, _session, socket) do
    record = Map.get(params, :record, %{})
    {:ok, Mob.Socket.assign(socket, :record, record)}
  end

  def render(assigns) do
    message = assigns.record
    email = message["email"] || "Unknown sender"
    body = message["message"] || ""
    timestamp = RemoteUI.short_time(message["inserted_at"])
    display_font = @display_font
    ui_font = @ui_font

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Message")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="contact_message_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            <Text
              text={email}
              text_size={:"2xl"}
              font={display_font}
              font_weight="bold"
              text_color={:on_surface}
            />
            <Text
              text={timestamp}
              text_size={:xs}
              font={ui_font}
              text_color={:secondary}
              padding_top={:space_xs}
            />
            <Spacer size={20} />
            <Box
              background={:surface}
              border_color={:border}
              border_width={1}
              corner_radius={:radius_md}
              padding={:space_lg}
              fill_width={true}
            >
              <Text
                text={body}
                text_size={:base}
                font={display_font}
                text_color={:on_surface}
                line_height={1.55}
              />
            </Box>
            <Spacer size={16} />
            <Row fill_width={true}>
              {button("Reply by email", :email, :primary, :on_primary)}
              <Spacer size={8} />
              {button("Copy", :copy, :surface_raised, :primary)}
            </Row>
            <Spacer size={8} />
            {button("Share message", :share, :surface, :secondary)}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, :email}, socket) do
    Mob.Device.open_url("mailto:" <> (socket.assigns.record["email"] || ""))
    {:noreply, socket}
  end

  def handle_info({:tap, :copy}, socket) do
    content = "#{socket.assigns.record["email"]}\n\n#{socket.assigns.record["message"]}"
    {:noreply, socket |> Mob.Clipboard.put(content) |> Mob.Alert.toast("Copied")}
  end

  def handle_info({:tap, :share}, socket) do
    {:noreply, Mob.Share.text(socket, socket.assigns.record["message"] || "")}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp button(label, tag, background, color) do
    tap = {self(), tag}
    font = @ui_font
    ~MOB(<Button
  text={label}
  font={font}
  background={background}
  text_color={color}
  weight={1}
  on_tap={tap}
/>)
  end
end
