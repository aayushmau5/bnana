defmodule Bnana.IncentivesScreen do
  @moduledoc "Shows why a saved link may be worth reading."

  use Mob.Screen

  alias Bnana.{Incentives, Links, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @italic_font "PlayfairDisplay-Italic"
  @ui_font "ShareTechMono-Regular"

  def mount(%{link_id: link_id}, _session, socket) do
    case Links.get_link(link_id) do
      nil ->
        {:ok,
         socket
         |> Mob.Socket.assign(:link_id, link_id)
         |> Mob.Socket.assign(:url, "")
         |> Mob.Socket.assign(:title, "Link not found")
         |> Mob.Socket.assign(:token, "")
         |> Mob.Socket.assign(:cached?, false)
         |> Mob.Socket.assign(:status, {:error, :not_found})}

      link ->
        socket =
          socket
          |> Mob.Socket.assign(:link_id, link.id)
          |> Mob.Socket.assign(:url, link.url)
          |> Mob.Socket.assign(:title, display_title(link))
          |> Mob.Socket.assign(:token, "")
          |> Mob.Socket.assign(:cached?, is_map(link.incentives))
          |> Mob.Socket.assign(:status, cached_status(link.incentives))

        {:ok, maybe_load(socket)}
    end
  end

  def render(assigns) do
    display_font = @display_font
    ui_font = @ui_font

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Incentives")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="incentives_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {RemoteUI.intro("Is it worth the detour?", "A few reasons to read the original, before you decide.")}
            <Spacer size={22} />
            <Text
              text={assigns.title}
              text_size={:lg}
              font={display_font}
              font_weight="bold"
              text_color={:on_surface}
            />
            <Text
              text={assigns.url}
              text_size={:xs}
              font={ui_font}
              text_color={:muted}
              padding_top={:space_xs}
            />
            <Spacer size={22} />
            {content(assigns)}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:change, :incentives_token, token}, socket) do
    {:noreply, Mob.Socket.assign(socket, :token, token)}
  end

  def handle_info({:tap, :connect_incentives}, socket) do
    case Incentives.save_token(socket.assigns.token) do
      :ok -> {:noreply, load(Mob.Socket.assign(socket, :token, ""))}
      {:error, _reason} -> {:noreply, Mob.Alert.toast(socket, "Enter the incentives token")}
    end
  end

  def handle_info({:tap, :retry_incentives}, socket), do: {:noreply, load(socket)}

  def handle_info({:tap, :replace_incentives_token}, socket) do
    :ok = Incentives.forget_token()
    {:noreply, Mob.Socket.assign(socket, :status, :needs_token)}
  end

  def handle_info({:tap, :open_link}, socket) do
    Mob.Device.open_url(socket.assigns.url)
    {:noreply, socket}
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:incentives_loaded, result}, socket) do
    case result do
      {:ok, incentives} ->
        socket =
          socket
          |> Mob.Socket.assign(:status, result)
          |> cache(incentives)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, Mob.Socket.assign(socket, :status, result)}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp load(socket) do
    receiver = self()
    url = socket.assigns.url
    Task.start(fn -> send(receiver, {:incentives_loaded, Incentives.fetch(url)}) end)
    Mob.Socket.assign(socket, :status, :loading)
  end

  defp maybe_load(%{assigns: %{status: {:ok, _result}}} = socket), do: socket
  defp maybe_load(socket), do: if(Incentives.configured?(), do: load(socket), else: socket)

  defp cache(socket, incentives) do
    case Links.get_link(socket.assigns.link_id) do
      nil ->
        Mob.Alert.toast(socket, "Shown, but the saved link is gone")

      link ->
        case Links.cache_incentives(link, incentives) do
          {:ok, _link} -> Mob.Socket.assign(socket, :cached?, true)
          {:error, _changeset} -> Mob.Alert.toast(socket, "Shown, but couldn’t save this brief")
        end
    end
  end

  defp cached_status(incentives) when is_map(incentives), do: {:ok, incentives}
  defp cached_status(_incentives), do: :needs_token

  defp display_title(%{title: title, url: url}) when title in [nil, ""], do: url
  defp display_title(%{title: title}), do: title

  defp content(%{status: :needs_token} = assigns) do
    font = @ui_font
    change = {self(), :incentives_token}
    tap = {self(), :connect_incentives}

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
        <Text text="Connect incentives" text_size={:lg} font={font} text_color={:on_surface} />
        <Text
          text="Enter the OCI API token once. It stays in this app’s private storage."
          text_size={:sm}
          font={font}
          text_color={:muted}
          line_height={1.4}
          padding_top={:space_xs}
        />
        <Spacer size={16} />
        <TextField
          id="incentives_token"
          placeholder="Incentives token"
          value={assigns.token}
          secure={true}
          return_key="done"
          on_change={change}
        />
        <Spacer size={12} />
        <Button
          text="Connect"
          font={font}
          background={:primary}
          text_color={:on_primary}
          on_tap={tap}
        />
      </Column>
    </Box>
    """
  end

  defp content(%{status: :loading}), do: RemoteUI.loading("Asking Eva what’s inside…")

  defp content(%{status: {:ok, result}}) do
    italic_font = @italic_font
    ui_font = @ui_font
    verdict = result |> Map.get("verdict", "consider") |> to_string() |> String.upcase()
    reason = Map.get(result, "reason", "Eva found a few things worth considering.")
    items = incentive_items(Map.get(result, "incentives", []))
    open = {self(), :open_link}
    verdict_color = verdict_color(verdict)

    ~MOB"""
    <Column fill_width={true}>
      <Box
        background={:surface_raised}
        border_color={verdict_color}
        border_width={1}
        corner_radius={:radius_lg}
        padding={:space_lg}
        fill_width={true}
      >
        <Column fill_width={true}>
          <Row fill_width={true}>
            <Text text="●" text_size={:sm} text_color={verdict_color} />
            <Spacer size={8} />
            <Text
              text={verdict}
              text_size={:xs}
              font={ui_font}
              text_color={verdict_color}
              letter_spacing={1.4}
            />
          </Row>
          <Text
            text={reason}
            text_size={:xl}
            font={italic_font}
            text_color={:on_surface}
            line_height={1.45}
            padding_top={:space_md}
          />
        </Column>
      </Box>
      <Spacer size={22} />
      <Text
        text="WHAT YOU’LL TAKE AWAY"
        text_size={:xs}
        font={ui_font}
        text_color={:secondary}
        letter_spacing={1.3}
      />
      <Spacer size={10} />
      <Column fill_width={true}>
        {items}
      </Column>
      <Spacer size={20} />
      <Button
        text="Read the original  ↗"
        font={ui_font}
        background={:primary}
        text_color={:on_primary}
        on_tap={open}
      />
    </Column>
    """
  end

  defp content(%{status: {:error, :not_found}}), do: RemoteUI.error(error_message(:not_found))

  defp content(%{status: {:error, reason}}) do
    font = @ui_font
    retry = {self(), :retry_incentives}
    replace = {self(), :replace_incentives_token}

    ~MOB"""
    <Column fill_width={true}>
      {RemoteUI.error(error_message(reason))}
      <Spacer size={12} />
      <Button
        text="Try again"
        font={font}
        background={:primary}
        text_color={:on_primary}
        on_tap={retry}
      />
      <Spacer size={8} />
      <Button
        text="Replace token"
        font={font}
        background={:surface}
        text_color={:muted}
        on_tap={replace}
      />
    </Column>
    """
  end

  defp incentive_items(items) when is_list(items) and items != [] do
    items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, index} -> incentive_item(item, index) end)
    |> Enum.intersperse(~MOB(<Spacer size={10} />))
  end

  defp incentive_items(_items) do
    font = @italic_font

    [
      ~MOB(<Text
  text="Eva didn’t find a strong takeaway yet."
  text_size={:base}
  font={font}
  text_color={:muted}
/>)
    ]
  end

  defp incentive_item(item, index) when is_map(item) do
    display_font = @display_font
    ui_font = @ui_font
    hook = Map.get(item, "hook", "A reason to read")
    takeaway = Map.get(item, "takeaway", "")
    number = index |> Integer.to_string() |> String.pad_leading(2, "0")

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_md}
      fill_width={true}
    >
      <Row fill_width={true} align="top">
        <Box background={:primary} corner_radius={:radius_pill} width={34} height={34} align="center">
          <Text text={number} text_size={:xs} font={ui_font} text_color={:on_primary} />
        </Box>
        <Spacer size={12} />
        <Column weight={1}>
          <Text
            text={hook}
            text_size={:lg}
            font={display_font}
            font_weight="bold"
            text_color={:on_surface}
          />
          <Text
            text={takeaway}
            text_size={:sm}
            font={ui_font}
            text_color={:muted}
            line_height={1.45}
            padding_top={:space_xs}
          />
        </Column>
      </Row>
    </Box>
    """
  end

  defp incentive_item(_item, _index), do: ~MOB(<Spacer size={0} />)

  defp verdict_color("READ"), do: :primary
  defp verdict_color("SKIP"), do: :error
  defp verdict_color(_verdict), do: :secondary

  defp error_message(:unauthorized), do: "The saved token was rejected. Replace it and try again."
  defp error_message(:not_found), do: "This saved link no longer exists."

  defp error_message("multiple_eva_sessions"),
    do: "Eva has more than one open session. Keep only the dedicated one."

  defp error_message("eva_unavailable"), do: "The dedicated Eva session is not open right now."
  defp error_message({:http, status}), do: "The incentives service returned HTTP #{status}."
  defp error_message(_reason), do: "Couldn’t reach Eva. Check Tailscale and try again."
end
