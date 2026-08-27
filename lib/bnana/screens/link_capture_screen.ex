defmodule Bnana.LinkCaptureScreen do
  @moduledoc "Saves a URL handed to Bnana by the iOS capture shortcut."

  use Mob.Screen

  alias Bnana.{Links, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @italic_font "PlayfairDisplay-Italic"
  @ui_font "ShareTechMono-Regular"

  def mount(%{url: url}, _session, socket) do
    title_status = fetch_title(url)

    {:ok,
     socket
     |> Mob.Socket.assign(:url, url)
     |> Mob.Socket.assign(:title, default_title(url))
     |> Mob.Socket.assign(:title_edited?, false)
     |> Mob.Socket.assign(:title_status, title_status)}
  end

  def render(assigns) do
    display_font = @display_font
    italic_font = @italic_font
    ui_font = @ui_font
    change = {self(), :link_title}
    save = {self(), :save_link}
    cancel = {self(), :cancel}

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Save link")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="link_capture_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            <Text
              text="Keep this one close."
              text_size={:"3xl"}
              font={display_font}
              font_weight="bold"
              text_color={:on_surface}
            />
            <Text
              text="Give it a useful name, then save it for later."
              text_size={:base}
              font={italic_font}
              text_color={:muted}
              padding_top={:space_xs}
            />
            <Spacer size={24} />
            <Text
              text="TITLE"
              text_size={:xs}
              font={ui_font}
              text_color={:secondary}
              letter_spacing={1.3}
            />
            <Spacer size={8} />
            <TextField
              id="link_title"
              placeholder="Link title"
              value={assigns.title}
              return_key="done"
              on_change={change}
            />
            {title_status(assigns.title_status)}
            <Spacer size={18} />
            <Box
              background={:surface}
              border_color={:border}
              border_width={1}
              corner_radius={:radius_md}
              padding={:space_md}
              fill_width={true}
            >
              <Text
                text={assigns.url}
                text_size={:sm}
                font={ui_font}
                text_color={:muted}
                line_height={1.4}
              />
            </Box>
            <Spacer size={20} />
            <Button
              text="Save link"
              font={ui_font}
              background={:primary}
              text_color={:on_primary}
              on_tap={save}
            />
            <Spacer size={10} />
            <Button
              text="Cancel"
              font={ui_font}
              background={:surface}
              text_color={:muted}
              on_tap={cancel}
            />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:change, :link_title, title}, socket) do
    {:noreply,
     socket
     |> Mob.Socket.assign(:title, title)
     |> Mob.Socket.assign(:title_edited?, true)}
  end

  def handle_info(
        {:link_title_fetched, {:ok, title}},
        %{assigns: %{title_edited?: false}} = socket
      ) do
    {:noreply,
     socket
     |> Mob.Socket.assign(:title, title)
     |> Mob.Socket.assign(:title_status, :found)}
  end

  def handle_info({:link_title_fetched, {:ok, _title}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :title_status, :found)}
  end

  def handle_info({:link_title_fetched, :error}, socket) do
    {:noreply, Mob.Socket.assign(socket, :title_status, :failed)}
  end

  def handle_info({:tap, :save_link}, socket) do
    case Links.create_link(%{url: socket.assigns.url, title: String.trim(socket.assigns.title)}) do
      {:ok, _link} ->
        send(self(), :refresh_links)
        {:noreply, Mob.Socket.pop_screen(socket)}

      {:error, _changeset} ->
        {:noreply, Mob.Alert.toast(socket, "Could not save this link")}
    end
  end

  def handle_info({:tap, action}, socket) when action in [:back, :cancel] do
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp default_title(url) do
    case URI.parse(url).host do
      host when is_binary(host) -> String.replace_prefix(host, "www.", "")
      _ -> ""
    end
  end

  defp fetch_title(url) do
    if Application.get_env(:bnana, :fetch_link_titles, true) do
      receiver = self()
      Task.start(fn -> send(receiver, {:link_title_fetched, Links.fetch_title(url)}) end)
      :loading
    else
      :idle
    end
  end

  defp title_status(:loading) do
    font = @italic_font

    ~MOB"""
    <Column fill_width={true} padding_top={:space_sm}>
      <Progress />
      <Text
        text="Fetching the page title…"
        text_size={:sm}
        font={font}
        text_color={:muted}
        padding_top={:space_xs}
      />
    </Column>
    """
  end

  defp title_status(:found) do
    font = @italic_font

    ~MOB(<Text
  text="Page title found."
  text_size={:sm}
  font={font}
  text_color={:secondary}
  padding_top={:space_xs}
/>)
  end

  defp title_status(:failed) do
    font = @italic_font

    ~MOB(<Text
  text="Couldn’t fetch the page title. You can still enter one."
  text_size={:sm}
  font={font}
  text_color={:muted}
  padding_top={:space_xs}
/>)
  end

  defp title_status(:idle), do: ~MOB(<Spacer size={0} />)
end
