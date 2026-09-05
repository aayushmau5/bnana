defmodule Bnana.WorkspacesScreen do
  @moduledoc "Native Notes workspace picker."

  use Mob.Screen

  alias Bnana.{PhoenixClient, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    PhoenixClient.subscribe()
    PhoenixClient.request("notes", "get-workspaces")
    {:ok, socket |> Mob.Socket.assign(:workspaces, nil) |> Mob.Socket.assign(:error, nil)}
  end

  def render(assigns) do
    content = workspace_content(assigns)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Notes")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="workspaces_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {RemoteUI.intro("Choose a corner.", "Workspaces live in Phoenix; the app keeps the view quiet and native.")}
            <Spacer size={22} />
            {content}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, {:open_workspace, id}}, socket) do
    case Enum.find(socket.assigns.workspaces || [], &(&1["id"] == id)) do
      nil ->
        {:noreply, socket}

      workspace ->
        {:noreply, Mob.Socket.push_screen(socket, Bnana.NotesScreen, %{workspace: workspace})}
    end
  end

  def handle_info({:phoenix_reply, _ref, "notes", "get-workspaces", {:ok, workspaces}}, socket) do
    {:noreply,
     socket |> Mob.Socket.assign(:workspaces, workspaces) |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:phoenix_reply, _ref, "notes", "get-workspaces", {:error, reason}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :error, "Could not load workspaces: #{inspect(reason)}")}
  end

  def handle_info({:phoenix_status, %{status: :connected}}, socket) do
    PhoenixClient.request("notes", "get-workspaces")
    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def terminate(_reason, _socket) do
    PhoenixClient.unsubscribe()
    :ok
  end

  defp workspace_content(%{workspaces: nil, error: nil}),
    do: RemoteUI.loading("Finding workspaces…")

  defp workspace_content(%{error: error}) when is_binary(error), do: RemoteUI.error(error)

  defp workspace_content(%{workspaces: []}) do
    font = @display_font
    ~MOB(<Text
  text="No Notes workspaces exist yet."
  text_size={:lg}
  font={font}
  text_color={:muted}
  text_align="center"
/>)
  end

  defp workspace_content(%{workspaces: workspaces}) do
    cards =
      workspaces
      |> Enum.map(&workspace_card/1)
      |> Enum.intersperse(~MOB(<Spacer size={10} />))

    ~MOB(<Column fill_width={true}>
  {cards}
</Column>)
  end

  defp workspace_card(workspace) do
    title = workspace["title"] || "Untitled workspace"
    visibility = if workspace["is_public"], do: "PUBLIC", else: "PRIVATE"
    tap = {self(), {:open_workspace, workspace["id"]}}
    display_font = @display_font
    ui_font = @ui_font

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_lg}
      fill_width={true}
      on_tap={tap}
    >
      <Row fill_width={true}>
        <Column weight={1}>
          <Text
            text={title}
            text_size={:xl}
            font={display_font}
            font_weight="bold"
            text_color={:on_surface}
          />
          <Text
            text={visibility}
            text_size={:xs}
            font={ui_font}
            text_color={:secondary}
            padding_top={:space_xs}
          />
        </Column>
        <Text text="→" text_size={:lg} text_color={:primary} />
      </Row>
    </Box>
    """
  end
end
