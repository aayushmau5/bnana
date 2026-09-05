defmodule Bnana.MemoryBookScreen do
  @moduledoc "A local, date-led journal of small memories."

  use Mob.Screen

  alias Bnana.Memories

  @display_font "PlayfairDisplay-Regular"
  @italic_font "PlayfairDisplay-Italic"
  @ui_font "ShareTechMono-Regular"
  @months ~w(January February March April May June July August September October November December)
  @weekdays ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

  def mount(_params, _session, socket) do
    {:ok, Mob.Socket.assign(socket, :memories, Memories.list_memories())}
  end

  def render(assigns) do
    content = memory_collection(assigns.memories)
    display_font = @display_font
    italic_font = @italic_font
    ui_font = @ui_font
    back = {self(), :back}
    create = {self(), :new_memory}

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="memory_book_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            <Row fill_width={true}>
              <Icon
                name="back"
                text="Go back"
                text_size={20.0}
                width={48}
                height={48}
                text_color={:on_surface}
                padding={:space_sm}
                on_tap={back}
              />
              <Spacer />
              <Box
                width={48}
                height={48}
                background={:primary}
                corner_radius={24}
                align="center"
                on_tap={create}
              >
                <Text text="+" text_size={28.0} font={ui_font} text_color={:on_primary} />
              </Box>
            </Row>
            <Spacer size={12} />
            <Text
              text="memory book."
              text_size={42.0}
              font={display_font}
              font_weight="bold"
              text_color={:on_surface}
            />
            <Text
              text="small days, kept gently."
              text_size={:base}
              font={italic_font}
              text_color={:muted}
              padding_top={:space_xs}
            />
            <Spacer size={30} />
            {content}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, :new_memory}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.MemoryBookEditorScreen)}
  end

  def handle_info({:tap, {:view_memory, id}}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.MemoryScreen, %{id: id})}
  end

  def handle_info(:refresh_memories, socket) do
    {:noreply, Mob.Socket.assign(socket, :memories, Memories.list_memories())}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp memory_collection([]) do
    display_font = @display_font
    italic_font = @italic_font

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_lg}
      padding={:space_lg}
      fill_width={true}
    >
      <Column fill_width={true}>
        <Text
          text="The first page is waiting."
          text_size={:xl}
          font={display_font}
          text_color={:on_surface}
          text_align="center"
        />
        <Text
          text="One sentence is enough."
          text_size={:base}
          font={italic_font}
          text_color={:muted}
          text_align="center"
          padding_top={:space_xs}
        />
      </Column>
    </Box>
    """
  end

  defp memory_collection(memories) do
    sections =
      memories
      |> Enum.chunk_by(&{&1.memory_date.year, &1.memory_date.month})
      |> Enum.map(&month_section/1)
      |> Enum.intersperse(~MOB(<Spacer size={28} />))

    ~MOB(<Column fill_width={true}>
  {sections}
</Column>)
  end

  defp month_section([first | _] = memories) do
    label = "#{Enum.at(@months, first.memory_date.month - 1)} #{first.memory_date.year}"
    ui_font = @ui_font

    entries =
      memories
      |> Enum.chunk_by(& &1.memory_date)
      |> Enum.map(&day_section/1)
      |> Enum.intersperse(~MOB(<Spacer size={14} />))

    ~MOB"""
    <Column fill_width={true}>
      <Row fill_width={true}>
        <Text
          text={String.upcase(label)}
          text_size={:xs}
          font={ui_font}
          text_color={:secondary}
          letter_spacing={1.3}
        />
        <Spacer size={12} />
        <Divider weight={1} />
      </Row>
      <Spacer size={16} />
      {entries}
    </Column>
    """
  end

  defp day_section([first | _] = memories) do
    day = first.memory_date.day |> Integer.to_string() |> String.pad_leading(2, "0")
    weekday = first.memory_date |> Date.day_of_week() |> then(&Enum.at(@weekdays, &1 - 1))
    display_font = @display_font
    ui_font = @ui_font

    cards =
      memories
      |> Enum.map(&memory_card/1)
      |> Enum.intersperse(~MOB(<Spacer size={10} />))

    ~MOB"""
    <Row fill_width={true} align="top">
      <Box width={48} align="center">
        <Column fill_width={true}>
          <Text
            text={day}
            text_size={:xl}
            font={display_font}
            text_color={:on_surface}
            text_align="center"
          />
          <Text
            text={String.slice(weekday, 0, 3) |> String.upcase()}
            text_size={:xs}
            font={ui_font}
            text_color={:muted}
            text_align="center"
            letter_spacing={1.0}
          />
        </Column>
      </Box>
      <Spacer size={12} />
      <Column weight={1} fill_width={true}>
        {cards}
      </Column>
    </Row>
    """
  end

  defp memory_card(memory) do
    photo = photo(memory.photo_path)
    display_font = @display_font
    ui_font = @ui_font
    view = {self(), {:view_memory, memory.id}}

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_lg}
      padding={:space_md}
      fill_width={true}
      on_tap={view}
    >
      <Column fill_width={true}>
        {photo}
        <Row fill_width={true}>
          <Text
            text="MEMORY"
            text_size={:xs}
            font={ui_font}
            text_color={:primary}
            letter_spacing={1.2}
          />
          <Spacer />
          <Text text="VIEW →" text_size={:xs} font={ui_font} text_color={:muted} />
        </Row>
        <Spacer size={8} />
        <Text
          text={memory.body}
          text_size={:base}
          font={display_font}
          text_color={:on_surface}
          line_height={1.5}
        />
      </Column>
    </Box>
    """
  end

  defp photo(nil), do: []
  defp photo(""), do: []

  defp photo(path) do
    ~MOB"""
    <Column fill_width={true}>
      <Box fill_width={true} align="center">
        <Image src={path} width={180} height={120} content_mode="fit" corner_radius={:radius_md} />
      </Box>
      <Spacer size={14} />
    </Column>
    """
  end
end
