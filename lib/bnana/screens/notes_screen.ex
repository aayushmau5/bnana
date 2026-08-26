defmodule Bnana.NotesScreen do
  @moduledoc false

  use Mob.Screen

  alias Bnana.{PhoenixClient, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(params, _session, socket) do
    PhoenixClient.subscribe()
    workspace = Map.get(params, :workspace, %{})
    load_notes(workspace["id"])

    {:ok,
     socket
     |> Mob.Socket.assign(:workspace, workspace)
     |> Mob.Socket.assign(:notes, nil)
     |> Mob.Socket.assign(:pending_delete, nil)
     |> Mob.Socket.assign(:error, nil)}
  end

  def render(assigns) do
    title = assigns.workspace["title"] || "Notes"
    content = notes_content(assigns)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header(title)}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="notes_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {new_note_button()}
            <Spacer size={18} />
            {content}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, :new_note}, socket) do
    params = %{kind: :new_note, workspace_id: socket.assigns.workspace["id"]}
    {:noreply, Mob.Socket.push_screen(socket, Bnana.RemoteEditorScreen, params)}
  end

  def handle_info({:tap, {:edit_note, id}}, socket) do
    case find_note(socket, id) do
      nil ->
        {:noreply, socket}

      note ->
        params = %{kind: :edit_note, workspace_id: socket.assigns.workspace["id"], record: note}
        {:noreply, Mob.Socket.push_screen(socket, Bnana.RemoteEditorScreen, params)}
    end
  end

  def handle_info({:tap, {:delete_note, id}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :pending_delete, id)}
  end

  def handle_info({:tap, :cancel_delete}, socket) do
    {:noreply, Mob.Socket.assign(socket, :pending_delete, nil)}
  end

  def handle_info({:tap, {:confirm_delete, id}}, socket) do
    PhoenixClient.request("notes", "delete", %{"id" => id})
    {:noreply, socket}
  end

  def handle_info({:phoenix_reply, _ref, "notes", "get-all", {:ok, data}}, socket) do
    {:noreply,
     socket |> Mob.Socket.assign(:notes, data["notes"] || []) |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:phoenix_reply, _ref, "notes", "delete", {:ok, _data}}, socket) do
    load_notes(socket.assigns.workspace["id"])
    {:noreply, socket |> Mob.Socket.assign(:pending_delete, nil) |> Mob.Alert.toast("Deleted")}
  end

  def handle_info({:phoenix_reply, _ref, "notes", _action, {:error, reason}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :error, "Notes request failed: #{inspect(reason)}")}
  end

  def handle_info({:phoenix_event, "notes-changed", %{"workspace_id" => id}}, socket) do
    if id == socket.assigns.workspace["id"], do: load_notes(id)
    {:noreply, socket}
  end

  def handle_info({:phoenix_status, %{status: :connected}}, socket) do
    load_notes(socket.assigns.workspace["id"])
    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def terminate(_reason, _socket) do
    PhoenixClient.unsubscribe()
    :ok
  end

  defp load_notes(workspace_id) do
    PhoenixClient.request("notes", "get-all", %{"workspace_id" => workspace_id})
  end

  defp find_note(socket, id), do: Enum.find(socket.assigns.notes || [], &(&1["id"] == id))

  defp notes_content(%{notes: nil, error: nil}), do: RemoteUI.loading("Opening notes…")
  defp notes_content(%{error: error}) when is_binary(error), do: RemoteUI.error(error)

  defp notes_content(%{notes: []}) do
    font = @display_font
    ~MOB(<Text
  text="No notes here yet."
  text_size={:lg}
  font={font}
  text_color={:muted}
  text_align="center"
/>)
  end

  defp notes_content(assigns) do
    cards =
      assigns.notes
      |> Enum.map(&note_card(&1, assigns.pending_delete))
      |> Enum.intersperse(~MOB(<Spacer size={10} />))

    ~MOB(<Column fill_width={true}>
  {cards}
</Column>)
  end

  defp note_card(note, pending_delete) do
    text = note["text"] || ""
    timestamp = RemoteUI.short_time(note["updated_at"] || note["inserted_at"])
    confirmation = if pending_delete == note["id"], do: delete_confirmation(note["id"]), else: []
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
        <Text
          text={text}
          text_size={:base}
          font={display_font}
          text_color={:on_surface}
          line_height={1.45}
        />
        <Text
          text={timestamp}
          text_size={:xs}
          font={ui_font}
          text_color={:muted}
          padding_top={:space_xs}
        />
        <Spacer size={12} />
        <Row fill_width={true}>
          {small_button("Edit", {:edit_note, note["id"]}, :surface_raised, :primary)}
          <Spacer size={8} />
          {small_button("Delete", {:delete_note, note["id"]}, :surface, :error)}
        </Row>
        {confirmation}
      </Column>
    </Box>
    """
  end

  defp delete_confirmation(id) do
    font = @ui_font

    ~MOB"""
    <Column fill_width={true}>
      <Spacer size={12} />
      <Text text="Delete this note?" text_size={:sm} font={font} text_color={:error} />
      <Spacer size={8} />
      <Row fill_width={true}>
        {small_button("Keep", :cancel_delete, :surface_raised, :on_surface)}
        <Spacer size={8} />
        {small_button("Delete", {:confirm_delete, id}, :error, :on_error)}
      </Row>
    </Column>
    """
  end

  defp new_note_button do
    tap = {self(), :new_note}
    font = @ui_font
    ~MOB(<Button
  text="+  New note"
  font={font}
  background={:primary}
  text_color={:on_primary}
  on_tap={tap}
/>)
  end

  defp small_button(label, tag, background, color) do
    tap = {self(), tag}
    font = @ui_font
    ~MOB(<Button
  text={label}
  font={font}
  text_size={:xs}
  background={background}
  text_color={color}
  weight={1}
  on_tap={tap}
/>)
  end
end
