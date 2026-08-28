defmodule Bnana.SavedLinksScreen do
  @moduledoc "Lists links captured on this device."

  use Mob.Screen

  alias Bnana.{Links, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Mob.Socket.assign(:links, Links.list_links())
     |> Mob.Socket.assign(:revealed_link_id, nil)
     |> Mob.Socket.assign(:pending_delete, nil)}
  end

  def render(assigns) do
    content = link_content(assigns.links, assigns.revealed_link_id, assigns.pending_delete)

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
    {:noreply, reload(socket)}
  end

  def handle_info({:tap, {:open_link, url}}, socket) do
    Mob.Device.open_url(url)
    {:noreply, socket}
  end

  def handle_info({:tap, {:show_incentives, link_id}}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.IncentivesScreen, %{link_id: link_id})}
  end

  def handle_info({:swipe_left, {:reveal_link_actions, link_id}}, socket) do
    {:noreply,
     socket
     |> Mob.Socket.assign(:revealed_link_id, link_id)
     |> Mob.Socket.assign(:pending_delete, nil)}
  end

  def handle_info({:swipe_right, :close_link_actions}, socket) do
    {:noreply,
     socket
     |> Mob.Socket.assign(:revealed_link_id, nil)
     |> Mob.Socket.assign(:pending_delete, nil)}
  end

  def handle_info({:tap, {:copy_link, url}}, socket) do
    socket = socket |> Mob.Clipboard.put(url) |> Mob.Alert.toast("Copied")
    {:noreply, Mob.Socket.assign(socket, :revealed_link_id, nil)}
  end

  def handle_info({:tap, {:set_link_read, link_id, read?}}, socket) do
    with link when not is_nil(link) <- Enum.find(socket.assigns.links, &(&1.id == link_id)),
         {:ok, _link} <- Links.set_read(link, read?) do
      {:noreply, reload(socket)}
    else
      nil -> {:noreply, reload(socket)}
      {:error, _changeset} -> {:noreply, Mob.Alert.toast(socket, "Could not update link")}
    end
  end

  def handle_info({:tap, {:delete_link, link_id}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :pending_delete, link_id)}
  end

  def handle_info({:tap, :cancel_delete}, socket) do
    {:noreply, Mob.Socket.assign(socket, :pending_delete, nil)}
  end

  def handle_info({:tap, {:confirm_delete, link_id}}, socket) do
    case Enum.find(socket.assigns.links, &(&1.id == link_id)) do
      nil ->
        {:noreply, reload(socket)}

      link ->
        case Links.delete_link(link) do
          {:ok, _link} -> {:noreply, reload(socket)}
          {:error, _changeset} -> {:noreply, Mob.Alert.toast(socket, "Could not delete link")}
        end
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp reload(socket) do
    socket
    |> Mob.Socket.assign(:links, Links.list_links())
    |> Mob.Socket.assign(:revealed_link_id, nil)
    |> Mob.Socket.assign(:pending_delete, nil)
  end

  defp link_content([], _revealed_link_id, _pending_delete) do
    font = @display_font

    ~MOB(<Text
  text="Nothing saved yet."
  text_size={:lg}
  font={font}
  text_color={:muted}
  text_align="center"
/>)
  end

  defp link_content(links, revealed_link_id, pending_delete) do
    cards =
      links
      |> Enum.map(&link_card(&1, revealed_link_id, pending_delete))
      |> Enum.intersperse(~MOB(<Spacer size={10} />))

    ~MOB(<Column fill_width={true}>
  {cards}
</Column>)
  end

  defp link_card(link, revealed_link_id, pending_delete) do
    title = if link.title in [nil, ""], do: link.url, else: link.title
    title_color = if link.read_at, do: :muted, else: :on_surface
    reveal = {self(), {:reveal_link_actions, link.id}}
    close = {self(), :close_link_actions}
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
      on_swipe_left={reveal}
      on_swipe_right={close}
    >
      <Column fill_width={true}>
        <Row fill_width={true}>
          <Text
            text={title}
            text_size={:lg}
            font={display_font}
            font_weight="bold"
            text_color={title_color}
          />
          <Spacer />
          {read_badge(link.read_at)}
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
        {link_actions(link, revealed_link_id == link.id)}
        {delete_confirmation(link.id, pending_delete)}
      </Column>
    </Box>
    """
  end

  defp link_actions(link, false) do
    incentives = {self(), {:show_incentives, link.id}}
    open = {self(), {:open_link, link.url}}
    incentives_id = "link_incentives_#{link.id}"
    ui_font = @ui_font

    ~MOB"""
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
        text="Open  ↗"
        text_size={:sm}
        font={ui_font}
        background={:surface_raised}
        text_color={:on_surface}
        weight={1}
        on_tap={open}
      />
    </Row>
    """
  end

  defp link_actions(link, true) do
    mark_read? = is_nil(link.read_at)
    toggle = {self(), {:set_link_read, link.id, mark_read?}}
    copy = {self(), {:copy_link, link.url}}
    delete = {self(), {:delete_link, link.id}}
    toggle_id = "link_read_#{link.id}"
    copy_id = "link_copy_#{link.id}"
    delete_id = "link_delete_#{link.id}"
    toggle_text = if mark_read?, do: "✓ Read", else: "Unread"
    toggle_background = if mark_read?, do: :primary, else: :surface_raised
    toggle_color = if mark_read?, do: :on_primary, else: :on_surface
    ui_font = @ui_font

    ~MOB"""
    <Row fill_width={true}>
      <Button
        id={toggle_id}
        text={toggle_text}
        text_size={:sm}
        font={ui_font}
        background={toggle_background}
        text_color={toggle_color}
        weight={1}
        on_tap={toggle}
      />
      <Spacer size={8} />
      <Button
        id={copy_id}
        text="Copy"
        text_size={:sm}
        font={ui_font}
        background={:surface_raised}
        text_color={:on_surface}
        weight={1}
        on_tap={copy}
      />
      <Spacer size={8} />
      <Box
        id={delete_id}
        background={:error}
        corner_radius={:radius_md}
        padding={:space_sm}
        weight={1}
        align="center"
        on_tap={delete}
      >
        <Icon name="trash" text="Delete link" text_size={20} text_color={:on_error} />
      </Box>
    </Row>
    """
  end

  defp read_badge(nil), do: []

  defp read_badge(_read_at) do
    font = @ui_font

    ~MOB(<Text text="✓ READ  " text_size={:xs} font={font} text_color={:primary} />)
  end

  defp delete_confirmation(id, id) do
    ui_font = @ui_font
    keep = {self(), :cancel_delete}
    delete = {self(), {:confirm_delete, id}}

    ~MOB"""
    <Column fill_width={true}>
      <Spacer size={12} />
      <Text text="Delete this link?" text_size={:sm} font={ui_font} text_color={:error} />
      <Spacer size={8} />
      <Row fill_width={true}>
        <Button
          text="Keep"
          text_size={:sm}
          font={ui_font}
          background={:surface_raised}
          text_color={:on_surface}
          weight={1}
          on_tap={keep}
        />
        <Spacer size={10} />
        <Button
          text="Delete"
          text_size={:sm}
          font={ui_font}
          background={:error}
          text_color={:on_error}
          weight={1}
          on_tap={delete}
        />
      </Row>
    </Column>
    """
  end

  defp delete_confirmation(_id, _pending_delete), do: []
end
