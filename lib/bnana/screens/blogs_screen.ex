defmodule Bnana.BlogsScreen do
  @moduledoc "Lists in-progress blog drafts and resumes their editor."
  use Mob.Screen

  alias Bnana.{Blogs, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @italic_font "PlayfairDisplay-Italic"
  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Mob.Socket.assign(:drafts, Blogs.list_drafts())
     |> Mob.Socket.assign(:pending_delete, nil)}
  end

  def render(assigns) do
    allow_auto_lock()
    drafts = draft_collection(assigns.drafts, assigns.pending_delete)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Blogs")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="blogs_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {intro()}
            <Spacer size={20} />
            {create_button()}
            <Spacer size={24} />
            {drafts}
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

  def handle_info({:tap, :create_draft}, socket) do
    case Blogs.create_draft() do
      {:ok, draft} ->
        {:noreply, Mob.Socket.push_screen(socket, Bnana.BlogEditorScreen, %{draft_id: draft.id})}

      {:error, _changeset} ->
        {:noreply, Mob.Alert.toast(socket, "Could not create the draft")}
    end
  end

  def handle_info({:tap, {:open_draft, id}}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.BlogEditorScreen, %{draft_id: id})}
  end

  def handle_info({:tap, {:delete_draft, id}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :pending_delete, id)}
  end

  def handle_info({:tap, {:confirm_delete, id}}, socket) do
    case Enum.find(socket.assigns.drafts, &(&1.id == id)) do
      nil -> :ok
      draft -> Blogs.delete_draft(draft)
    end

    {:noreply, reload(socket)}
  end

  def handle_info({:tap, :cancel_delete}, socket) do
    {:noreply, Mob.Socket.assign(socket, :pending_delete, nil)}
  end

  def handle_info(:refresh_drafts, socket), do: {:noreply, reload(socket)}
  def handle_info(_message, socket), do: {:noreply, socket}

  defp reload(socket) do
    socket
    |> Mob.Socket.assign(:drafts, Blogs.list_drafts())
    |> Mob.Socket.assign(:pending_delete, nil)
  end

  # Mob handles the native edge-back gesture before the editor sees it, so the
  # parent render is the one reliable place to release the app-scoped idle timer.
  defp allow_auto_lock do
    if Process.whereis(:mob_screen) == self(), do: Mob.Device.keep_awake(false)
  end

  defp intro do
    italic_font = @italic_font
    ui_font = @ui_font

    ~MOB"""
    <Column fill_width={true}>
      <Text
        text="Write whenever it finds you."
        text_size={:lg}
        text_color={:on_surface}
        font={italic_font}
      />
      <Text
        text="Everything here is saved as a work in progress."
        text_size={:sm}
        text_color={:muted}
        font={ui_font}
        padding_top={:space_xs}
      />
    </Column>
    """
  end

  defp create_button do
    ui_font = @ui_font
    tap = {self(), :create_draft}

    ~MOB(<Button
  text="+  Start a new blog"
  text_size={:base}
  font={ui_font}
  background={:primary}
  text_color={:on_primary}
  on_tap={tap}
/>)
  end

  defp draft_collection([], _pending_delete) do
    italic_font = @italic_font

    ~MOB"""
    <Box background={:surface} padding={:space_lg} fill_width={true}>
      <Text
        text="No wandering thoughts yet."
        text_size={:lg}
        text_color={:muted}
        font={italic_font}
        text_align="center"
      />
    </Box>
    """
  end

  defp draft_collection(drafts, pending_delete) do
    cards =
      drafts
      |> Enum.map(&draft_card(&1, pending_delete))
      |> Enum.intersperse(~MOB(<Spacer size={12} />))

    ~MOB"""
    <Column fill_width={true}>
      {cards}
    </Column>
    """
  end

  defp draft_card(draft, pending_delete) do
    confirmation = delete_confirmation(draft.id, pending_delete)

    ~MOB"""
    <Box background={:surface} padding={:space_md} fill_width={true}>
      <Row fill_width={true}>
        {draft_open_target(draft)}
        {delete_button(draft.id)}
      </Row>
      {confirmation}
    </Box>
    """
  end

  defp delete_confirmation(id, id) do
    ui_font = @ui_font

    confirmation =
      ~MOB"""
      <Box background={:surface_raised} padding={:space_md} fill_width={true}>
        <Column fill_width={true}>
          <Text text="Delete this draft?" text_size={:sm} text_color={:on_surface} font={ui_font} />
          <Spacer size={12} />
          <Row fill_width={true}>
            {confirmation_button("Keep it", :cancel_delete, :surface, :on_surface)}
            <Spacer size={10} />
            {confirmation_button("Delete", {:confirm_delete, id}, :error, :on_error)}
          </Row>
        </Column>
      </Box>
      """

    [~MOB(<Spacer size={14} />), confirmation]
  end

  defp delete_confirmation(_id, _pending_delete), do: []

  defp confirmation_button(label, tag, background, text_color) do
    ui_font = @ui_font
    tap = {self(), tag}

    ~MOB(<Button
  text={label}
  text_size={:sm}
  font={ui_font}
  background={background}
  text_color={text_color}
  weight={1}
  on_tap={tap}
/>)
  end

  defp draft_open_target(draft) do
    id = "open_draft_#{draft.id}"
    tap = {self(), {:open_draft, draft.id}}

    ~MOB"""
    <Box id={id} weight={1} on_tap={tap}>
      <Row fill_width={true}>
        {draft_copy(draft)}
      </Row>
    </Box>
    """
  end

  defp draft_copy(draft) do
    display_font = @display_font
    ui_font = @ui_font
    title = display_title(draft.title)
    status = "WIP  ·  #{relative_time(draft.updated_at)}"
    body = excerpt(draft.body)

    ~MOB"""
    <Column weight={1}>
      <Text
        text={title}
        text_size={:lg}
        text_color={:on_surface}
        font={display_font}
        font_weight="semibold"
      />
      <Text
        text={status}
        text_size={:xs}
        text_color={:primary}
        font={ui_font}
        padding_top={:space_xs}
      />
      <Text
        text={body}
        text_size={:sm}
        text_color={:muted}
        font={display_font}
        padding_top={:space_xs}
      />
    </Column>
    """
  end

  defp delete_button(id) do
    ui_font = @ui_font
    element_id = "delete_draft_#{id}"
    tap = {self(), {:delete_draft, id}}

    ~MOB(<Button
  id={element_id}
  text="Delete"
  text_size={:xs}
  font={ui_font}
  text_color={:error}
  background={:surface}
  fill_width={false}
  width={72}
  on_tap={tap}
/>)
  end

  defp display_title(title) when title in [nil, ""], do: "Untitled draft"
  defp display_title(title), do: title

  defp excerpt(body) when body in [nil, ""], do: "Tap to catch the first thought…"

  defp excerpt(body) do
    body
    |> String.replace(~r/[#*_>`\[\]()\n]+/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 90)
  end

  defp relative_time(nil), do: "just now"

  defp relative_time(updated_at) do
    seconds = max(DateTime.diff(DateTime.utc_now(), updated_at, :second), 0)

    cond do
      seconds < 60 -> "just now"
      seconds < 3_600 -> "#{div(seconds, 60)}m ago"
      seconds < 86_400 -> "#{div(seconds, 3_600)}h ago"
      true -> "#{div(seconds, 86_400)}d ago"
    end
  end
end
