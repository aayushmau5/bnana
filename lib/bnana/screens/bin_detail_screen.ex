defmodule Bnana.BinDetailScreen do
  @moduledoc false

  use Mob.Screen

  alias Bnana.{PhoenixClient, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(params, _session, socket) do
    record = Map.get(params, :record, %{})

    {:ok,
     socket
     |> Mob.Socket.assign(:record, record)
     |> Mob.Socket.assign(:confirm_delete, false)}
  end

  def render(assigns) do
    paste = assigns.record
    title = paste["title"] || "Untitled paste"
    content = paste["content"] || ""
    expires = "Expires " <> RemoteUI.short_time(paste["expire_at"], "sometime")
    display_font = @display_font
    ui_font = @ui_font

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Paste")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="bin_detail_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            <Text
              text={title}
              text_size={:"3xl"}
              font={display_font}
              font_weight="bold"
              text_color={:on_surface}
            />
            <Text
              text={expires}
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
              padding={:space_md}
              fill_width={true}
            >
              <Text
                text={content}
                text_size={:sm}
                font={ui_font}
                text_color={:on_surface}
                line_height={1.5}
              />
            </Box>
            <Spacer size={16} />
            <Row fill_width={true}>
              {action_button("Copy", :copy, :surface_raised, :primary)}
              <Spacer size={8} />
              {action_button("Share", :share, :surface_raised, :secondary)}
            </Row>
            <Spacer size={8} />
            <Row fill_width={true}>
              {action_button("Edit", :edit, :primary, :on_primary)}
              <Spacer size={8} />
              {action_button("Delete", :delete, :surface, :error)}
            </Row>
            {delete_confirmation(assigns.confirm_delete)}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, :copy}, socket) do
    socket =
      socket
      |> Mob.Clipboard.put(socket.assigns.record["content"] || "")
      |> Mob.Alert.toast("Copied")

    {:noreply, socket}
  end

  def handle_info({:tap, :share}, socket) do
    {:noreply, Mob.Share.text(socket, socket.assigns.record["content"] || "")}
  end

  def handle_info({:tap, :edit}, socket) do
    params = %{kind: :edit_bin, record: socket.assigns.record}
    {:noreply, Mob.Socket.push_screen(socket, Bnana.RemoteEditorScreen, params)}
  end

  def handle_info({:tap, :delete}, socket) do
    {:noreply, Mob.Socket.assign(socket, :confirm_delete, true)}
  end

  def handle_info({:tap, :cancel_delete}, socket) do
    {:noreply, Mob.Socket.assign(socket, :confirm_delete, false)}
  end

  def handle_info({:tap, :confirm_delete}, socket) do
    PhoenixClient.request("bin", "delete", %{"id" => socket.assigns.record["id"]})
    {:noreply, socket}
  end

  def handle_info({:phoenix_reply, _ref, "bin", "delete", {:ok, %{"status" => "OK"}}}, socket) do
    socket = Mob.Alert.toast(socket, "Deleted")
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  def handle_info({:phoenix_reply, _ref, "bin", "delete", result}, socket) do
    {:noreply, Mob.Alert.toast(socket, "Delete failed: #{inspect(result)}")}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp action_button(label, tag, background, text_color) do
    tap = {self(), tag}
    font = @ui_font
    ~MOB(<Button
  text={label}
  font={font}
  background={background}
  text_color={text_color}
  weight={1}
  on_tap={tap}
/>)
  end

  defp delete_confirmation(false), do: []

  defp delete_confirmation(true) do
    font = @ui_font

    ~MOB"""
    <Column fill_width={true}>
      <Spacer size={12} />
      <Box
        background={:surface_raised}
        border_color={:error}
        border_width={1}
        corner_radius={:radius_md}
        padding={:space_md}
        fill_width={true}
      >
        <Column fill_width={true}>
          <Text text="Delete this paste?" text_size={:sm} font={font} text_color={:on_surface} />
          <Spacer size={10} />
          <Row fill_width={true}>
            {action_button("Keep", :cancel_delete, :surface, :on_surface)}
            <Spacer size={8} />
            {action_button("Delete", :confirm_delete, :error, :on_error)}
          </Row>
        </Column>
      </Box>
    </Column>
    """
  end
end
