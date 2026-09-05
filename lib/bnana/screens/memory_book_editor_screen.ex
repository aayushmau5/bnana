defmodule Bnana.MemoryBookEditorScreen do
  @moduledoc "Focused Memory Book composer with optional native photo capture."

  use Mob.Screen

  alias Bnana.{Memories, Photos, RemoteUI}

  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Mob.Socket.assign(:body, "")
     |> Mob.Socket.assign(:photo_source, nil)
     |> Mob.Socket.assign(:photo_action, nil)
     |> Mob.Socket.assign(:keyboard_open, false)
     |> Mob.Socket.assign(:web_ready, false)
     |> Mob.Socket.assign(:saving, false)}
  end

  def render(assigns) do
    actions = editor_actions(assigns)
    url = editor_url()

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("New memory")}
      <WebView url={url} weight={1} show_url={false} />
      {actions}
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, :capture_photo}, %{assigns: %{photo_action: nil}} = socket) do
    socket = Mob.Socket.assign(socket, :photo_action, :camera)
    {:noreply, request_camera(socket)}
  end

  def handle_info({:tap, :capture_photo}, socket), do: {:noreply, socket}

  def handle_info(
        {:permission, :camera, :granted},
        %{assigns: %{photo_action: :camera}} = socket
      ) do
    {:noreply, open_camera(socket)}
  end

  def handle_info({:permission, :camera, :denied}, socket) do
    {:noreply, photo_error(socket, "Camera access is needed to take a photo")}
  end

  def handle_info({:tap, :choose_photo}, %{assigns: %{photo_action: nil}} = socket) do
    socket = Mob.Socket.assign(socket, :photo_action, :photos)
    {:noreply, open_photo_picker(socket)}
  end

  def handle_info({:tap, :choose_photo}, socket), do: {:noreply, socket}

  def handle_info({:camera, :photo, item}, socket) do
    {:noreply, attach_photo(socket, item)}
  end

  def handle_info({:camera, :cancelled}, socket), do: {:noreply, finish_photo_action(socket)}

  def handle_info({:camera, :not_available}, socket) do
    {:noreply, photo_error(socket, "Camera is not available on this device")}
  end

  def handle_info({:camera, :error, _reason}, socket) do
    {:noreply, photo_error(socket, "Could not open the camera")}
  end

  def handle_info({:photos, :picked, items}, socket) when is_list(items) do
    case Enum.find(items, &valid_photo_item?/1) do
      nil -> {:noreply, photo_error(socket, "Choose a supported image file")}
      item -> {:noreply, attach_photo(socket, item)}
    end
  end

  def handle_info({:photos, :picked, _invalid}, socket) do
    {:noreply, photo_error(socket, "Could not read that photo")}
  end

  def handle_info({:photos, :cancelled}, socket), do: {:noreply, finish_photo_action(socket)}

  def handle_info({:photos, :error, _reason}, socket) do
    {:noreply, photo_error(socket, "Could not open Photos")}
  end

  def handle_info({:tap, :remove_photo}, socket) do
    {:noreply, Mob.Socket.assign(socket, :photo_source, nil)}
  end

  def handle_info({:tap, :save_memory}, %{assigns: %{saving: true}} = socket),
    do: {:noreply, socket}

  def handle_info({:tap, :save_memory}, socket) do
    body = String.trim(socket.assigns.body)

    if body == "" do
      {:noreply, Mob.Alert.toast(socket, "Write a little something first")}
    else
      save_memory(socket, body)
    end
  end

  def handle_info({:webview, :message, json}, socket) when is_binary(json) do
    case :json.decode(json) do
      message when is_map(message) -> handle_editor_message(message, socket)
      _other -> {:noreply, socket}
    end
  rescue
    _error -> {:noreply, socket}
  end

  def handle_info({:webview, :message, message}, socket) when is_map(message) do
    handle_editor_message(message, socket)
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp handle_editor_message(%{"event" => "ready"}, socket) do
    socket = Mob.Socket.assign(socket, :web_ready, true)
    {:noreply, send_initial_state(socket)}
  end

  defp handle_editor_message(%{"event" => "change", "body" => body}, socket)
       when is_binary(body) do
    {:noreply, Mob.Socket.assign(socket, :body, body)}
  end

  defp handle_editor_message(%{"event" => "keyboard", "open" => open}, socket)
       when is_boolean(open) do
    {:noreply, Mob.Socket.assign(socket, :keyboard_open, open)}
  end

  defp handle_editor_message(_message, socket), do: {:noreply, socket}

  defp save_memory(socket, body) do
    socket = Mob.Socket.assign(socket, :saving, true)

    case Memories.create_memory(%{body: body, photo_source: socket.assigns.photo_source}) do
      {:ok, _memory} ->
        send(self(), :refresh_memories)
        {:noreply, Mob.Socket.pop_screen(socket)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> Mob.Socket.assign(:saving, false)
         |> Mob.Alert.toast("Could not keep the memory")}
    end
  end

  defp attach_photo(socket, item) do
    path = item_path(item)

    case Memories.validate_photo_source(path) do
      :ok ->
        socket
        |> Mob.Socket.assign(:photo_source, path)
        |> finish_photo_action()

      {:error, :invalid_photo} ->
        photo_error(socket, "Could not read that photo")
    end
  end

  defp valid_photo_item?(item) do
    match?(:ok, item |> item_path() |> Memories.validate_photo_source())
  end

  defp item_path(item) when is_map(item), do: Map.get(item, :path)
  defp item_path(_item), do: nil

  defp request_camera(socket) do
    Mob.Permissions.request(socket, :camera)
  rescue
    error in [ArgumentError, UndefinedFunctionError, ErlangError] ->
      photo_error(socket, Exception.message(error))
  end

  defp open_camera(socket) do
    MobCamera.capture_photo(socket, quality: :high)
  rescue
    error in [ArgumentError, UndefinedFunctionError, ErlangError] ->
      photo_error(socket, Exception.message(error))
  end

  defp open_photo_picker(socket) do
    Photos.pick(socket)
  rescue
    error in [ArgumentError, UndefinedFunctionError, ErlangError] ->
      photo_error(socket, Exception.message(error))
  end

  defp photo_error(socket, message) do
    socket
    |> finish_photo_action()
    |> Mob.Alert.toast(message)
  end

  defp finish_photo_action(socket), do: Mob.Socket.assign(socket, :photo_action, nil)

  defp editor_actions(%{keyboard_open: true}), do: []

  defp editor_actions(assigns) do
    photo = photo_preview(assigns.photo_source)
    ui_font = @ui_font
    capture = {self(), :capture_photo}
    choose = {self(), :choose_photo}
    save = {self(), :save_memory}
    save_label = if assigns.saving, do: "Keeping…", else: "Keep this memory"

    capture_label =
      if assigns.photo_action == :camera, do: "Opening camera…", else: "◎  Take a photo"

    choose_label = if assigns.photo_action == :photos, do: "Opening…", else: "Choose"

    ~MOB"""
    <Column
      background={:surface}
      border_color={:border}
      border_width={1}
      padding={:space_md}
      fill_width={true}
    >
      {photo}
      <Text
        text="PHOTO · OPTIONAL"
        text_size={:xs}
        font={ui_font}
        text_color={:muted}
        letter_spacing={1.1}
      />
      <Spacer size={8} />
      <Row fill_width={true}>
        <Button
          text={capture_label}
          text_size={:sm}
          font={ui_font}
          background={:surface_raised}
          text_color={:on_surface}
          weight={1}
          on_tap={capture}
        />
        <Spacer size={8} />
        <Button
          text={choose_label}
          text_size={:sm}
          font={ui_font}
          background={:surface_raised}
          text_color={:on_surface}
          weight={1}
          on_tap={choose}
        />
      </Row>
      <Spacer size={10} />
      <Button
        text={save_label}
        font={ui_font}
        background={:primary}
        text_color={:on_primary}
        on_tap={save}
      />
    </Column>
    """
  end

  defp photo_preview(nil), do: []

  defp photo_preview(path) do
    ui_font = @ui_font
    remove = {self(), :remove_photo}

    ~MOB"""
    <Column fill_width={true}>
      <Box fill_width={true} align="center">
        <Image src={path} width={268} height={146} content_mode="fit" corner_radius={:radius_md} />
      </Box>
      <Spacer size={8} />
      <Button
        text="Remove photo"
        text_size={:xs}
        font={ui_font}
        background={:surface}
        text_color={:error}
        on_tap={remove}
      />
      <Spacer size={10} />
    </Column>
    """
  end

  defp send_initial_state(%{assigns: %{web_ready: true}} = socket) do
    Mob.WebView.post_message(socket, %{
      "event" => "init",
      "body" => socket.assigns.body,
      "date" => long_date(Memories.local_today())
    })
  end

  defp send_initial_state(socket), do: socket

  defp long_date(date) do
    month =
      Enum.at(
        ~w(January February March April May June July August September October November December),
        date.month - 1
      )

    weekday =
      Enum.at(
        ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday),
        Date.day_of_week(date) - 1
      )

    "#{weekday} · #{month} #{date.day}"
  end

  defp editor_url do
    "file://#{Bnana.App.priv_path("webviews/memory_book_editor/index.html")}"
  end
end
