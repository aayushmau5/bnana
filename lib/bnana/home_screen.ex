defmodule Bnana.HomeScreen do
  @moduledoc "Landing screen for Bnana."
  use Mob.Screen

  @regular_font "PlayfairDisplay-Regular"
  @mono_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    Mob.Theme.set(MobThemes.Obsidian)
    {:ok, socket}
  end

  def render(_assigns) do
    ui_font = @regular_font

    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg}>
        <Text
          text="Bnana"
          text_size={48.0}
          font={ui_font}
          font_weight="bold"
          text_color={:on_surface}
          padding={:space_sm}
        />
        <Spacer size={20} />
        {nav_button("Blogs", :open_blogs)}
        <Spacer size={12} />
      </Column>
    </Scroll>
    """
  end

  def handle_info({:tap, :open_blogs}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.BlogsScreen)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp nav_button(label, tag) do
    tap = {self(), tag}
    display_font = @mono_font

    ~MOB(<Button text={label} text_color={:on_primary} text_size={:md} font={display_font} on_tap={tap} />)
  end
end
