defmodule Bnana.SavedLinksScreen do
  @moduledoc "Lists links captured on this device."

  use Mob.Screen

  alias Bnana.{Links, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    {:ok, Mob.Socket.assign(socket, :links, Links.list_links())}
  end

  def render(assigns) do
    content = link_content(assigns.links)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Saved links")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="saved_links_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {RemoteUI.intro("A trail back.", "Links saved from around your phone, ready when you are.")}
            <Spacer size={22} />
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

  def handle_info(:refresh_links, socket) do
    {:noreply, Mob.Socket.assign(socket, :links, Links.list_links())}
  end

  def handle_info({:tap, {:open_link, url}}, socket) do
    Mob.Device.open_url(url)
    {:noreply, socket}
  end

  def handle_info({:tap, {:show_incentives, link_id}}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.IncentivesScreen, %{link_id: link_id})}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp link_content([]) do
    font = @display_font

    ~MOB(<Text
  text="Nothing saved yet."
  text_size={:lg}
  font={font}
  text_color={:muted}
  text_align="center"
/>)
  end

  defp link_content(links) do
    cards = links |> Enum.map(&link_card/1) |> Enum.intersperse(~MOB(<Spacer size={10} />))

    ~MOB(<Column fill_width={true}>
  {cards}
</Column>)
  end

  defp link_card(link) do
    title = if link.title in [nil, ""], do: link.url, else: link.title
    open = {self(), {:open_link, link.url}}
    incentives = {self(), {:show_incentives, link.id}}
    incentives_id = "link_incentives_#{link.id}"
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
          <Text text="↗" text_size={:base} font={ui_font} text_color={:primary} />
        </Row>
        <Text
          text={link.url}
          text_size={:xs}
          font={ui_font}
          text_color={:muted}
          padding_top={:space_xs}
        />
        <Spacer size={14} />
        <Row fill_width={true}>
          <Button
            id={incentives_id}
            text="Incentives"
            text_size={:sm}
            font={ui_font}
            background={:primary}
            text_color={:on_primary}
            weight={1}
            on_tap={incentives}
          />
          <Spacer size={10} />
          <Button
            text="Read  ↗"
            text_size={:sm}
            font={ui_font}
            background={:surface_raised}
            text_color={:on_surface}
            weight={1}
            on_tap={open}
          />
        </Row>
      </Column>
    </Box>
    """
  end
end
