defmodule Bnana.LastTimeScreen do
  @moduledoc "A little memory for everyday life."
  use Mob.Screen
  alias Bnana.{LastTime, RemoteUI}

  def mount(_params, _session, socket) do
    refresh_token = make_ref()
    Process.send_after(self(), {:last_time_tick, refresh_token}, 60_000)

    {:ok,
     socket
     |> Mob.Socket.assign(:refresh_token, refresh_token)
     |> Mob.Socket.assign(:items, LastTime.list())
     |> Mob.Socket.assign(:editor, nil)
     |> Mob.Socket.assign(:selected, nil)
     |> Mob.Socket.assign(:history, [])
     |> Mob.Socket.assign(:date, Date.to_iso8601(LastTime.today()))
     |> Mob.Socket.assign(:pending_delete, nil)
     |> Mob.Socket.assign(:error, nil)}
  end

  def render(assigns) do
    content = if assigns.editor, do: editor(assigns.editor), else: collection(assigns)
    error = if assigns.error, do: RemoteUI.error(assigns.error), else: []

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Last time")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="last_time_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            <Text
              text="a little memory for everyday life."
              font="PlayfairDisplay-Italic"
              text_size={:lg}
              text_color={:muted}
            />
            <Spacer size={20} />
            {error}
            {content}
            <Spacer size={24} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, %{assigns: %{editor: editor}} = socket) when not is_nil(editor),
    do: {:noreply, Mob.Socket.assign(socket, :editor, nil)}

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, :new}, socket) do
    {:noreply,
     socket
     |> Mob.Socket.assign(:editor, %{id: nil, name: "", rhythm: ""})
     |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:change, field, value}, socket) when field in [:name, :rhythm] do
    {:noreply, Mob.Socket.assign(socket, :editor, Map.put(socket.assigns.editor, field, value))}
  end

  def handle_info({:change, :date, value}, socket),
    do: {:noreply, Mob.Socket.assign(socket, :date, value)}

  def handle_info({:tap, :save}, socket) do
    editor = socket.assigns.editor

    case LastTime.save(editor.id, editor.name, editor.rhythm) do
      {:ok, _} -> {:noreply, socket |> Mob.Socket.assign(:editor, nil) |> refresh()}
      {:error, message} -> {:noreply, Mob.Socket.assign(socket, :error, message)}
    end
  end

  def handle_info({:tap, {:edit, id}}, socket) do
    item = Enum.find(socket.assigns.items, &(&1["id"] == id))
    editor = %{id: id, name: item["name"], rhythm: to_string(item["interval_days"] || "")}
    {:noreply, Mob.Socket.assign(socket, :editor, editor)}
  end

  def handle_info({:tap, {:details, id}}, socket) do
    selected = if socket.assigns.selected == id, do: nil, else: id

    {:noreply,
     socket
     |> Mob.Socket.assign(:selected, selected)
     |> Mob.Socket.assign(:pending_delete, nil)
     |> refresh()}
  end

  def handle_info({:tap, {:log, id}}, socket), do: log(socket, id, LastTime.today())

  def handle_info({:tap, {:yesterday, id}}, socket),
    do: log(socket, id, Date.add(LastTime.today(), -1))

  def handle_info({:tap, {:backdate, id}}, socket), do: log(socket, id, socket.assigns.date)
  def handle_info({:tap, {:pin, id}}, socket), do: result(socket, LastTime.pin(id))

  def handle_info({:tap, {:remove_event, id}}, socket),
    do: result(socket, LastTime.undo(id))

  def handle_info({:tap, {:delete, id}}, socket),
    do: {:noreply, Mob.Socket.assign(socket, :pending_delete, id)}

  def handle_info({:tap, :cancel_delete}, socket),
    do: {:noreply, Mob.Socket.assign(socket, :pending_delete, nil)}

  def handle_info({:tap, {:confirm_delete, id}}, socket) do
    result(socket, LastTime.delete(id))
  end

  def handle_info({:last_time_tick, token}, %{assigns: %{refresh_token: token}} = socket) do
    Process.send_after(self(), {:last_time_tick, token}, 60_000)
    error = socket.assigns.error
    {:noreply, socket |> refresh() |> Mob.Socket.assign(:error, error)}
  end

  def handle_info(:refresh_last_time, socket), do: {:noreply, refresh(socket)}
  def handle_info({:tap, :refresh}, socket), do: {:noreply, refresh(socket)}
  def handle_info(_message, socket), do: {:noreply, socket}

  defp log(socket, id, date) do
    case LastTime.log(id, date) do
      {:ok, _event_id} -> {:noreply, refresh(socket)}
      {:error, message} -> {:noreply, Mob.Socket.assign(socket, :error, message)}
    end
  end

  defp result(socket, result) do
    case result do
      {:ok, _} ->
        {:noreply, refresh(socket)}

      {:error, message} ->
        {:noreply, Mob.Socket.assign(socket, :error, message)}
    end
  end

  defp refresh(socket) do
    history = if socket.assigns.selected, do: LastTime.history(socket.assigns.selected), else: []

    socket
    |> Mob.Socket.assign(:items, LastTime.list())
    |> Mob.Socket.assign(:history, history)
    |> Mob.Socket.assign(:error, nil)
  end

  defp editor(editor) do
    name_change = {self(), :name}
    rhythm_change = {self(), :rhythm}

    ~MOB"""
    <Column fill_width={true}>
      {RemoteUI.eyebrow("What did you do?")}
      <Spacer size={8} />
      <TextField
        id="last_time_name"
        placeholder="Watered plants"
        value={editor.name}
        on_change={name_change}
      />
      <Spacer size={20} />
      {RemoteUI.eyebrow("Roughly every … days (optional)")}
      <Spacer size={8} />
      <TextField
        id="last_time_rhythm"
        placeholder="e.g. 7 — or leave blank"
        value={editor.rhythm}
        on_change={rhythm_change}
      />
      <Text
        text="A gentle amber hint when due. No rhythm needed."
        text_color={:muted}
        text_size={:sm}
        padding_top={:space_sm}
      />
      <Spacer size={20} />
      {button("Save", :save, true)}
      {button("Cancel", :back)}
    </Column>
    """
  end

  defp collection(assigns) do
    cards = Enum.map(assigns.items, &card(&1, assigns))

    empty =
      if assigns.items == [],
        do: ~MOB(<Text
  text="When did you last…? Add a chore, a little care, or something you love. Then log whenever it happens."
  font="PlayfairDisplay-Regular"
  text_size={:xl}
  text_color={:muted}
  padding={:space_lg}
/>),
        else: []

    ~MOB"""
    <Column fill_width={true}>
      {button("+  Something to remember", :new, true)}
      <Text
        text="Pin up to three favourites for your home screen."
        text_size={:sm}
        text_color={:muted}
        padding_top={:space_sm}
      />
      <Spacer size={20} />
      {empty}
      {cards}
      {button("Refresh", :refresh)}
    </Column>
    """
  end

  defp card(item, assigns) do
    id = item["id"]
    due = LastTime.due?(item, LastTime.today())
    color = if due, do: :secondary, else: :muted
    elapsed = LastTime.elapsed(item["last_on"], LastTime.today())

    rhythm =
      if item["interval_days"],
        do: "About every #{item["interval_days"]} days" <> if(due, do: " · due again", else: ""),
        else: "Whenever you feel like it"

    pin = if item["pinned"] == 1, do: "Unpin", else: "Pin to widget"
    details = if assigns.selected == id, do: details(item, assigns), else: []

    ~MOB"""
    <Column fill_width={true}>
      <Box
        background={:surface}
        border_color={color}
        border_width={1}
        corner_radius={:radius_lg}
        padding={:space_md}
        fill_width={true}
      >
        <Column fill_width={true}>
          <Text
            text={item["name"]}
            font="PlayfairDisplay-Regular"
            text_size={:xl}
            text_color={:on_surface}
          />
          <Text
            text={elapsed}
            font="ShareTechMono-Regular"
            text_size={:lg}
            text_color={color}
            padding_top={:space_sm}
          />
          <Text text={rhythm} text_size={:sm} text_color={:muted} padding_top={:space_xs} />
          <Spacer size={12} />
          {button("Did it again", {:log, id}, true)}
          <Row fill_width={true}>
            {button(pin, {:pin, id})}
            <Spacer size={8} />
            {button("History & edit", {:details, id})}
          </Row>
          {details}
        </Column>
      </Box>
      <Spacer size={14} />
    </Column>
    """
  end

  defp details(item, assigns) do
    id = item["id"]
    date_change = {self(), :date}

    history =
      Enum.map(assigns.history, fn event ->
        ~MOB"""
        <Row fill_width={true}>
          <Text text={event["occurred_on"]} text_size={:sm} text_color={:muted} />
          <Spacer />
          {button("Remove log", {:remove_event, event["id"]})}
        </Row>
        """
      end)

    confirmation =
      if assigns.pending_delete == id do
        ~MOB"""
        <Column fill_width={true}>
          <Text text="Delete this counter and all its history?" text_color={:error} text_size={:sm} />
          {button("Delete counter & history", {:confirm_delete, id})}
          {button("Keep it", :cancel_delete)}
        </Column>
        """
      else
        []
      end

    ~MOB"""
    <Column fill_width={true}>
      <Spacer size={16} />
      {RemoteUI.eyebrow("Remembered afterward?")}
      {button("Did it yesterday", {:yesterday, id})}
      <Text text="Or choose a date (YYYY-MM-DD)" text_size={:sm} text_color={:muted} />
      <TextField
        id="last_time_date"
        value={assigns.date}
        placeholder="YYYY-MM-DD"
        on_change={date_change}
      />
      {button("Log this date", {:backdate, id})}
      <Spacer size={12} />
      {RemoteUI.eyebrow("History")}
      {history}
      {button("Edit name & rhythm", {:edit, id})}
      {button("Delete counter…", {:delete, id})}
      {confirmation}
    </Column>
    """
  end

  defp button(text, tag, primary \\ false) do
    tap = {self(), tag}
    background = if primary, do: :primary, else: :surface
    color = if primary, do: :on_primary, else: :primary
    ~MOB(<Button
  text={text}
  font="ShareTechMono-Regular"
  text_size={:sm}
  background={background}
  text_color={color}
  on_tap={tap}
/>)
  end
end
