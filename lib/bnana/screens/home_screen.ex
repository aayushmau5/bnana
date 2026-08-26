defmodule Bnana.HomeScreen do
  @moduledoc "Landing screen for Bnana."
  use Mob.Screen

  @regular_font "PlayfairDisplay-Regular"
  @italic_font "PlayfairDisplay-Italic"
  @mono_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(_assigns) do
    regular_font = @regular_font
    italic_font = @italic_font
    mono_font = @mono_font

    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg} fill_width={true}>
        <Row fill_width={true}>
          <Text
            text="bnana."
            text_size={52.0}
            font={regular_font}
            font_weight="bold"
            text_color={:on_surface}
          />
          <Spacer />
          <Text text="✦" text_size={26.0} text_color={:secondary} padding_top={:space_sm} />
        </Row>
        <Text
          text="a small place for you :)"
          text_size={:lg}
          font={italic_font}
          text_color={:muted}
          line_height={1.35}
          padding_top={:space_xs}
        />
        <Spacer size={42} />
        <Box
          background={:surface}
          border_color={:border}
          border_width={1}
          corner_radius={:radius_lg}
          padding={:space_lg}
        >
          <Column fill_width={true}>
            <Row fill_width={true}>
              <Text
                text="CURRENTLY GROWING"
                text_size={:xs}
                font={mono_font}
                text_color={:secondary}
                letter_spacing={1.4}
              />
              <Spacer />
              <Text text="· ✦ ·" text_size={:sm} text_color={:primary} />
            </Row>
            <Spacer size={22} />
            <Text
              text="Blogs"
              text_size={36.0}
              font={regular_font}
              font_weight="bold"
              text_color={:on_surface}
            />
            <Text
              text="Unfinished, unhurried, and saved before they wander off."
              text_size={:base}
              font={italic_font}
              text_color={:muted}
              line_height={1.4}
              padding_top={:space_xs}
            />
            <Spacer size={24} />
            {nav_button("wander in  →", :open_blogs)}
          </Column>
        </Box>
        <Spacer size={16} />
        <Box
          background={:surface}
          border_color={:border}
          border_width={1}
          corner_radius={:radius_lg}
          padding={:space_lg}
        >
          <Column fill_width={true}>
            <Text
              text="PHOENIX WINDOW"
              text_size={:xs}
              font={mono_font}
              text_color={:secondary}
              letter_spacing={1.4}
            />
            <Spacer size={16} />
            <Text
              text="Site tools"
              text_size={32.0}
              font={regular_font}
              font_weight="bold"
              text_color={:on_surface}
            />
            <Text
              text="Stats, notes, pastes, comments and messages. Live from Phoenix."
              text_size={:base}
              font={italic_font}
              text_color={:muted}
              line_height={1.4}
              padding_top={:space_xs}
            />
            <Spacer size={20} />
            {nav_button("open the window  →", :open_phoenix)}
          </Column>
        </Box>
        <Spacer size={24} />
      </Column>
    </Scroll>
    """
  end

  def handle_info({:tap, :open_blogs}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.BlogsScreen)}
  end

  def handle_info({:tap, :open_phoenix}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.PhoenixScreen)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp nav_button(label, tag) do
    tap = {self(), tag}
    display_font = @mono_font

    ~MOB(<Button
  text={label}
  text_color={:on_primary}
  text_size={:base}
  font={display_font}
  background={:primary}
  on_tap={tap}
/>)
  end
end
