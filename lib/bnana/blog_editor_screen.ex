defmodule Bnana.BlogEditorScreen do
  @moduledoc "Persistent Markdown editor backed by the bundled local editor page."
  use Mob.Screen

  alias Bnana.Blogs

  @autosave_delay 450

  def mount(params, _session, socket) do
    draft = Blogs.get_draft!(params.draft_id)

    {:ok,
     socket
     |> Mob.Socket.assign(:draft, draft)
     |> Mob.Socket.assign(:dirty, false)
     |> Mob.Socket.assign(:save_token, nil)
     |> Mob.Socket.assign(:save_timer, nil)
     |> Mob.Socket.assign(:web_ready, false)}
  end

  def render(_assigns) do
    url = editor_url()

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      <WebView url={url} weight={1} show_url={false} />
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket) do
    socket = persist_now(socket)
    send(self(), :refresh_drafts)
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  def handle_info({:webview, :message, json}, socket) when is_binary(json) do
    case :json.decode(json) do
      message when is_map(message) -> handle_editor_message(message, socket)
      _ -> {:noreply, socket}
    end
  rescue
    _ -> {:noreply, socket}
  end

  def handle_info({:webview, :message, message}, socket) when is_map(message) do
    handle_editor_message(message, socket)
  end

  def handle_info({:persist_draft, token}, %{assigns: %{save_token: token}} = socket) do
    {:noreply, persist_now(socket)}
  end

  def handle_info({:persist_draft, _stale_token}, socket), do: {:noreply, socket}

  def handle_info({:mob_device, :did_enter_background}, socket) do
    {:noreply, persist_now(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp handle_editor_message(%{"event" => "ready"}, socket) do
    socket = Mob.Socket.assign(socket, :web_ready, true)
    {:noreply, send_initial_draft(socket)}
  end

  defp handle_editor_message(%{"event" => "change"} = message, socket) do
    draft = socket.assigns.draft

    updated = %{
      draft
      | title: binary_value(message["title"], draft.title),
        body: binary_value(message["body"], draft.body),
        cursor_position: integer_value(message["cursor"], draft.cursor_position),
        editor_mode: editor_mode(message["mode"], draft.editor_mode)
    }

    {:noreply,
     socket
     |> Mob.Socket.assign(:draft, updated)
     |> schedule_save()}
  end

  defp handle_editor_message(%{"event" => "view_state"} = message, socket) do
    draft = socket.assigns.draft

    updated = %{
      draft
      | cursor_position: integer_value(message["cursor"], draft.cursor_position),
        editor_mode: editor_mode(message["mode"], draft.editor_mode)
    }

    {:noreply,
     socket
     |> Mob.Socket.assign(:draft, updated)
     |> schedule_save()}
  end

  defp handle_editor_message(%{"event" => "back"}, socket) do
    socket = persist_now(socket)
    send(self(), :refresh_drafts)
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  defp handle_editor_message(_message, socket), do: {:noreply, socket}

  defp schedule_save(socket) do
    cancel_timer(socket.assigns.save_timer)
    token = make_ref()
    timer = Process.send_after(self(), {:persist_draft, token}, @autosave_delay)

    socket
    |> Mob.Socket.assign(:dirty, true)
    |> Mob.Socket.assign(:save_token, token)
    |> Mob.Socket.assign(:save_timer, timer)
    |> send_to_editor(%{"event" => "save_state", "state" => "saving"})
  end

  defp persist_now(%{assigns: %{dirty: false}} = socket), do: socket

  defp persist_now(socket) do
    cancel_timer(socket.assigns.save_timer)
    draft = socket.assigns.draft
    persisted_draft = Blogs.get_draft!(draft.id)

    attrs = %{
      title: draft.title,
      body: draft.body,
      editor_mode: draft.editor_mode,
      cursor_position: draft.cursor_position
    }

    case Blogs.update_draft(persisted_draft, attrs) do
      {:ok, saved} ->
        socket
        |> Mob.Socket.assign(:draft, saved)
        |> Mob.Socket.assign(:dirty, false)
        |> Mob.Socket.assign(:save_token, nil)
        |> Mob.Socket.assign(:save_timer, nil)
        |> send_to_editor(%{"event" => "save_state", "state" => "saved"})

      {:error, _changeset} ->
        socket
        |> Mob.Socket.assign(:save_token, nil)
        |> Mob.Socket.assign(:save_timer, nil)
        |> send_to_editor(%{"event" => "save_state", "state" => "error"})
    end
  end

  defp send_initial_draft(socket) do
    draft = socket.assigns.draft

    send_to_editor(socket, %{
      "event" => "init",
      "title" => draft.title,
      "body" => draft.body,
      "mode" => draft.editor_mode,
      "cursor" => draft.cursor_position
    })
  end

  defp send_to_editor(%{assigns: %{web_ready: true}} = socket, message) do
    Mob.WebView.post_message(socket, message)
  end

  defp send_to_editor(socket, _message), do: socket

  defp editor_url do
    "file://#{Bnana.App.priv_path("editor/index.html")}"
  end

  defp binary_value(value, _fallback) when is_binary(value), do: value
  defp binary_value(_value, fallback), do: fallback

  defp integer_value(value, _fallback) when is_integer(value) and value >= 0, do: value
  defp integer_value(_value, fallback), do: fallback

  defp editor_mode(value, _fallback) when value in ["edit", "preview"], do: value
  defp editor_mode(_value, fallback), do: fallback

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(token), do: Process.cancel_timer(token)
end
