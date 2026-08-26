defmodule Bnana.BinScreen do
  @moduledoc "Native list of Phoenix Bin pastes."

  use Mob.Screen

  alias Bnana.{PhoenixClient, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    PhoenixClient.subscribe()
    load_pastes()

    {:ok,
     socket
     |> Mob.Socket.assign(:pastes, nil)
     |> Mob.Socket.assign(:error, nil)}
  end

  def render(assigns) do
    content = paste_content(assigns)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Bin")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="bin_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {RemoteUI.intro("Things kept for a while.", "Create, read, edit and clear pastes without leaving the app.")}
            <Spacer size={18} />
            {new_button()}
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

  def handle_info({:tap, :new_bin}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.RemoteEditorScreen, %{kind: :new_bin})}
  end

  def handle_info({:tap, {:open_bin, id}}, socket) do
    case Enum.find(socket.assigns.pastes || [], &(&1["id"] == id)) do
      nil -> {:noreply, socket}
      paste -> {:noreply, Mob.Socket.push_screen(socket, Bnana.BinDetailScreen, %{record: paste})}
    end
  end

  def handle_info({:phoenix_reply, _ref, "bin", "get-all", {:ok, pastes}}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:pastes, pastes) |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:phoenix_reply, _ref, "bin", "get-all", {:error, reason}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :error, "Could not load Bin: #{inspect(reason)}")}
  end

  def handle_info({:phoenix_event, event, _payload}, socket)
      when event in ["bin-created", "bin-updated", "bin-deleted"] do
    load_pastes()
    {:noreply, socket}
  end

  def handle_info({:phoenix_status, %{status: :connected}}, socket) do
    load_pastes()
    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def terminate(_reason, _socket) do
    PhoenixClient.unsubscribe()
    :ok
  end

  defp load_pastes, do: PhoenixClient.request("bin", "get-all")

  defp paste_content(%{pastes: nil, error: nil}), do: RemoteUI.loading("Opening Bin…")
  defp paste_content(%{error: error}) when is_binary(error), do: RemoteUI.error(error)

  defp paste_content(%{pastes: []}) do
    font = @display_font

    ~MOB(<Text text="Bin is empty." text_size={:lg} font={font} text_color={:muted} text_align="center" />)
  end

  defp paste_content(%{pastes: pastes}) do
    cards =
      pastes
      |> Enum.map(&paste_card/1)
      |> Enum.intersperse(~MOB(<Spacer size={10} />))

    ~MOB(<Column fill_width={true}>
  {cards}
</Column>)
  end

  defp paste_card(paste) do
    title = blank_fallback(paste["title"], "Untitled paste")
    excerpt = paste["content"] |> blank_fallback("Empty paste") |> String.slice(0, 120)
    expires = "expires #{RemoteUI.short_time(paste["expire_at"], "sometime")}"
    tap = {self(), {:open_bin, paste["id"]}}
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
            text={title}
            text_size={:lg}
            font={display_font}
            font_weight="bold"
            text_color={:on_surface}
          />
          <Spacer />
          <Text text="→" text_size={:base} text_color={:primary} />
        </Row>
        <Text
          text={expires}
          text_size={:xs}
          font={ui_font}
          text_color={:secondary}
          padding_top={:space_xs}
        />
        <Text
          text={excerpt}
          text_size={:sm}
          font={ui_font}
          text_color={:muted}
          line_height={1.35}
          padding_top={:space_xs}
        />
      </Column>
    </Box>
    """
  end

  defp new_button do
    font = @ui_font
    tap = {self(), :new_bin}
    ~MOB(<Button
  text="+  New paste"
  font={font}
  background={:primary}
  text_color={:on_primary}
  on_tap={tap}
/>)
  end

  defp blank_fallback(value, fallback) when value in [nil, ""], do: fallback
  defp blank_fallback(value, _fallback), do: value
end
