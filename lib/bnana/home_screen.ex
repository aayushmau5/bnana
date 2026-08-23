defmodule Bnana.HomeScreen do
  @moduledoc "Landing screen for Bnana."
  use Mob.Screen

  def mount(_params, _session, socket) do
    theme = Mob.State.get(:theme, :dark)
    Mob.Theme.set(theme_to_module(theme))
    # Activated plugins that ship a demo screen show up here automatically —
    # no edits needed when you add or remove one in mob.exs.
    {:ok, Mob.Socket.assign(socket, theme: theme, plugin_screens: Mob.Plugins.screens())}
  end

  def render(assigns) do
    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg}>
        <Image src={logo_src()} width={120} height={120} content_mode="fit" />
        <Spacer size={16} />
        <Text text="Bnana" text_size={:xl} text_color={:on_surface} padding={:space_sm} />
        <Text text="BEAM running on device" text_size={:sm} text_color={:primary} padding={4} />
        <Spacer size={40} />
        {nav_button("Text Input",          :open_text)}
        <Spacer size={12} />
        {nav_button("Rock Paper Scissors", :open_list)}
        <Spacer size={12} />
        {nav_button("Roll Dice",           :open_dice)}
        <Spacer size={12} />
        {nav_button("WebView",             :open_webview)}
        <Spacer size={12} />
        {nav_button("Audio",               :open_audio)}
        <Spacer size={12} />
        {nav_button("Storage",             :open_storage)}
        {plugin_section(assigns.plugin_screens)}
        <Spacer size={32} />
        <Text text="Theme" text_size={:sm} text_color={:muted} padding={4} />
        <Spacer size={8} />
        <Row fill_width={true}>
          {theme_tab("Light", :light, assigns.theme)}
          <Spacer size={8} />
          {theme_tab("Dark",  :dark,  assigns.theme)}
        </Row>
        <Spacer size={8} />
        <Row fill_width={true}>
          {theme_tab("Material 3",   :material3, assigns.theme)}
          <Spacer size={8} />
          {theme_tab("Liquid Glass", :glass,     assigns.theme)}
        </Row>
      </Column>
    </Scroll>
    """
  end

  def handle_info({:tap, :theme_light}, socket) do
    Mob.Theme.set(Mob.Theme.Light)
    Mob.State.put(:theme, :light)
    {:noreply, Mob.Socket.assign(socket, :theme, :light)}
  end

  def handle_info({:tap, :theme_dark}, socket) do
    Mob.Theme.set(Mob.Theme.Dark)
    Mob.State.put(:theme, :dark)
    {:noreply, Mob.Socket.assign(socket, :theme, :dark)}
  end

  def handle_info({:tap, :theme_material3}, socket) do
    Mob.Theme.set(MobThemes.Material3)
    Mob.State.put(:theme, :material3)
    {:noreply, Mob.Socket.assign(socket, :theme, :material3)}
  end

  def handle_info({:tap, :theme_glass}, socket) do
    Mob.Theme.set(MobThemes.ObsidianGlass)
    Mob.State.put(:theme, :glass)
    {:noreply, Mob.Socket.assign(socket, :theme, :glass)}
  end

  def handle_info({:tap, :open_text}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.TextScreen)}
  end

  def handle_info({:tap, :open_list}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.ListScreen)}
  end

  def handle_info({:tap, :open_dice}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.DiceScreen)}
  end

  def handle_info({:tap, :open_webview}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.WebViewScreen)}
  end

  def handle_info({:tap, :open_audio}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.AudioScreen)}
  end

  def handle_info({:tap, :open_storage}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Bnana.StorageScreen)}
  end

  # Plugin demo screens are tagged by their route string (see plugin_section/1).
  def handle_info({:tap, route}, socket) when is_binary(route) do
    case Enum.find(socket.assigns.plugin_screens, &(&1.default_route == route)) do
      %{module: mod} -> {:noreply, Mob.Socket.push_screen(socket, mod)}
      nil -> {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp nav_button(label, tag) do
    tap = {self(), tag}
    ~MOB(<Button
  text={label}
  background={:primary}
  text_color={:on_primary}
  text_size={:lg}
  padding={:space_md}
  fill_width={true}
  on_tap={tap}
/>)
  end

  # A nav button per activated plugin that declares a screen, built from the
  # live plugin registry so the list tracks mob.exs with no edits here.
  defp plugin_section([]), do: %{type: :column, props: %{}, children: []}

  defp plugin_section(screens) do
    heading = %{
      type: :text,
      props: %{text: "Device Plugins", text_size: :sm, text_color: :muted, padding: 4},
      children: []
    }

    spacer = %{type: :spacer, props: %{size: 12}, children: []}

    buttons =
      Enum.flat_map(screens, fn %{default_route: route} ->
        [spacer, nav_button(plugin_label(route), route)]
      end)

    %{type: :column, props: %{fill_width: true}, children: [spacer, heading | buttons]}
  end

  # "/mob_camera/demo" -> "Camera". Falls back gracefully for any route shape.
  defp plugin_label(route) do
    route
    |> String.trim_leading("/")
    |> String.split("/")
    |> List.first()
    |> to_string()
    |> String.replace_prefix("mob_", "")
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp theme_tab(label, key, active) do
    {bg, fg} = if key == active, do: {:primary, :on_primary}, else: {:surface, :on_surface}
    tap = {self(), :"theme_#{key}"}
    ~MOB(<Button
  text={label}
  background={bg}
  text_color={fg}
  text_size={:sm}
  padding={:space_sm}
  weight={1}
  on_tap={tap}
/>)
  end

  defp theme_to_module(:light), do: Mob.Theme.Light
  defp theme_to_module(:dark), do: Mob.Theme.Dark
  defp theme_to_module(:material3), do: MobThemes.Material3
  defp theme_to_module(:glass), do: MobThemes.ObsidianGlass
  defp theme_to_module(_), do: Mob.Theme.Dark

  defp logo_src() do
    case System.get_env("MOB_BEAMS_DIR") do
      nil -> Application.app_dir(:bnana, "priv/images/bnana.png")
      beams_dir -> Path.join(beams_dir, "priv/images/bnana.png")
    end
  end

  # defp rootdir do
  #   case System.get_env("ROOTDIR") do
  #     nil -> Path.expand("~/.mob/runtime/ios-sim")
  #     val -> val
  #   end
  # end
end
