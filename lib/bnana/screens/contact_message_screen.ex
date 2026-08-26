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
