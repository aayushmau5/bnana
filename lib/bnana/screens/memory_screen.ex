defmodule Bnana.MemoryScreen do
  @moduledoc "A quiet reading view for one Memory Book entry."

  use Mob.Screen

  alias Bnana.{Memories, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"
  @months ~w(January February March April May June July August September October November December)

  def mount(%{id: id}, _session, socket) do
    {:ok,
     socket
     |> Mob.Socket.assign(:memory, Memories.get_memory(id))
     |> Mob.Socket.assign(:confirm_delete, false)}
  end

  def render(assigns) do
    content = memory_content(assigns.memory, assigns.confirm_delete)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Memory")}
      <Scroll background={:background}>
        <Column padding={:space_lg} fill_width={true}>
          {content}
          <Spacer size={:space_xl} />
        </Column>
      </Scroll>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, :delete_memory}, socket) do
    {:noreply, Mob.Socket.assign(socket, :confirm_delete, true)}
  end

  def handle_info({:tap, :cancel_delete}, socket) do
    {:noreply, Mob.Socket.assign(socket, :confirm_delete, false)}
  end

  def handle_info({:tap, :confirm_delete}, %{assigns: %{memory: memory}} = socket) do
    case Memories.delete_memory(memory) do
      {:ok, _memory} ->
        send(self(), :refresh_memories)
        {:noreply, Mob.Socket.pop_screen(socket)}

      {:error, _changeset} ->
        {:noreply, Mob.Alert.toast(socket, "Could not delete the memory")}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp memory_content(nil, _confirm_delete) do
    display_font = @display_font

    ~MOB(<Text
  text="This memory is no longer here."
  text_size={:xl}
  font={display_font}
  text_color={:muted}
  text_align="center"
/>)
  end

  defp memory_content(memory, confirm_delete) do
    display_font = @display_font
    ui_font = @ui_font
    date = format_date(memory.memory_date)
    photo = photo(memory.photo_path)
    confirmation = delete_confirmation(confirm_delete)
    delete = {self(), :delete_memory}

    ~MOB"""
    <Column fill_width={true}>
      <Text
        text={String.upcase(date)}
        text_size={:xs}
        font={ui_font}
        text_color={:secondary}
        letter_spacing={1.3}
      />
      <Spacer size={14} />
      {photo}
      <Text
        text={memory.body}
        text_size={:lg}
        font={display_font}
        text_color={:on_surface}
        line_height={1.65}
      />
      <Spacer size={28} />
      <Button
        text="Delete memory"
        text_size={:sm}
        font={ui_font}
        background={:surface}
        text_color={:error}
        on_tap={delete}
      />
      {confirmation}
    </Column>
    """
  end

  defp delete_confirmation(false), do: []

  defp delete_confirmation(true) do
    ui_font = @ui_font
    keep = {self(), :cancel_delete}
    delete = {self(), :confirm_delete}

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
          <Text
            text="Delete this memory and its photo?"
            text_size={:sm}
            font={ui_font}
            text_color={:on_surface}
          />
          <Spacer size={10} />
          <Row fill_width={true}>
            <Button
              text="Keep it"
              font={ui_font}
              background={:surface}
              text_color={:on_surface}
              weight={1}
              on_tap={keep}
            />
            <Spacer size={8} />
            <Button
              text="Delete"
              font={ui_font}
              background={:error}
              text_color={:on_error}
              weight={1}
              on_tap={delete}
            />
          </Row>
        </Column>
      </Box>
    </Column>
    """
  end

  defp photo(nil), do: []
  defp photo(""), do: []

  defp photo(path) do
    ~MOB"""
    <Column fill_width={true}>
      <Box fill_width={true} align="center">
        <Image src={path} width={268} height={220} content_mode="fit" corner_radius={:radius_lg} />
      </Box>
      <Spacer size={20} />
    </Column>
    """
  end

  defp format_date(date) do
    weekday =
      date
      |> Date.day_of_week()
      |> then(&Enum.at(~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday), &1 - 1))

    "#{weekday} · #{Enum.at(@months, date.month - 1)} #{date.day}, #{date.year}"
  end
end
