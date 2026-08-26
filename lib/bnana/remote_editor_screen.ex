defmodule Bnana.RemoteEditorScreen do
  @moduledoc "Focused WebView editor for Phoenix resources that need multiline input."

  use Mob.Screen

  alias Bnana.PhoenixClient

  def mount(params, _session, socket) do
    kind = params.kind
    record = Map.get(params, :record, %{})

    {:ok,
     socket
     |> Mob.Socket.assign(:kind, kind)
     |> Mob.Socket.assign(:record, record)
     |> Mob.Socket.assign(:workspace_id, params[:workspace_id])
     |> Mob.Socket.assign(:blog_slug, params[:blog_slug])
     |> Mob.Socket.assign(:parent_id, params[:parent_id])
     |> Mob.Socket.assign(:title, record["title"] || "")
     |> Mob.Socket.assign(:body, editor_body(kind, record))
     |> Mob.Socket.assign(:expiry, "day")
     |> Mob.Socket.assign(:saving, false)
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

  def handle_info({:webview, :message, json}, socket) when is_binary(json) do
    case JSON.decode(json) do
      {:ok, message} when is_map(message) -> handle_editor_message(message, socket)
      _ -> {:noreply, socket}
    end
  end

  def handle_info({:webview, :message, message}, socket) when is_map(message) do
    handle_editor_message(message, socket)
  end

  def handle_info({:phoenix_reply, _ref, _event, _action, {:ok, response}}, socket) do
    case response do
      %{"status" => "ERROR", "message" => message} ->
        socket = socket |> Mob.Socket.assign(:saving, false) |> editor_state("error", message)
        {:noreply, socket}

      _ ->
        socket = Mob.Alert.toast(socket, "Saved")
        {:noreply, Mob.Socket.pop_screen(socket)}
    end
  end

  def handle_info({:phoenix_reply, _ref, _event, _action, {:error, reason}}, socket) do
    message = if is_binary(reason), do: reason, else: inspect(reason)
    socket = socket |> Mob.Socket.assign(:saving, false) |> editor_state("error", message)
    {:noreply, socket}
  end

  def handle_info({:mob_device, :did_enter_background}, socket) do
    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp handle_editor_message(%{"event" => "ready"}, socket) do
    socket = Mob.Socket.assign(socket, :web_ready, true)
    {:noreply, send_initial_state(socket)}
  end

  defp handle_editor_message(%{"event" => "change"} = message, socket) do
    {:noreply,
     socket
     |> Mob.Socket.assign(:title, binary(message["title"]))
     |> Mob.Socket.assign(:body, binary(message["body"]))
     |> Mob.Socket.assign(:expiry, expiry(message["expiry"]))}
  end

  defp handle_editor_message(%{"event" => "save"} = message, socket) do
    socket =
      socket
      |> Mob.Socket.assign(:title, binary(message["title"]))
      |> Mob.Socket.assign(:body, binary(message["body"]))
      |> Mob.Socket.assign(:expiry, expiry(message["expiry"]))

    if valid?(socket) do
      request_save(socket)
      {:noreply, socket |> Mob.Socket.assign(:saving, true) |> editor_state("saving")}
    else
      {:noreply, editor_state(socket, "error", "Write something before saving")}
    end
  end

  defp handle_editor_message(%{"event" => "back"}, socket) do
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  defp handle_editor_message(_message, socket), do: {:noreply, socket}

  defp request_save(%{assigns: %{kind: :new_note}} = socket) do
    PhoenixClient.request("notes", "new", %{
      "workspace_id" => socket.assigns.workspace_id,
      "text" => socket.assigns.body
    })
  end

  defp request_save(%{assigns: %{kind: :edit_note}} = socket) do
    PhoenixClient.request("notes", "edit", %{
      "id" => socket.assigns.record["id"],
      "workspace_id" => socket.assigns.workspace_id,
      "text" => socket.assigns.body
    })
  end

  defp request_save(%{assigns: %{kind: :new_bin}} = socket) do
    PhoenixClient.request("bin", "new", %{
      "title" => socket.assigns.title,
      "content" => socket.assigns.body,
      "expire" => expiry_payload(socket.assigns.expiry)
    })
  end

  defp request_save(%{assigns: %{kind: :edit_bin}} = socket) do
    files =
      socket.assigns.record
      |> Map.get("files", [])
      |> Enum.map(&%{"removed" => false, "file" => &1})

    PhoenixClient.request("bin", "edit", %{
      "id" => socket.assigns.record["id"],
      "title" => socket.assigns.title,
      "content" => socket.assigns.body,
      "expire" => %{"time" => 0, "unit" => socket.assigns.expiry},
      "files" => files
    })
  end

  defp request_save(%{assigns: %{kind: :reply_comment}} = socket) do
    PhoenixClient.request("comments", "reply", %{
      "blog_slug" => socket.assigns.blog_slug,
      "parent_id" => socket.assigns.parent_id,
      "content" => socket.assigns.body,
      "author" => "Aayush"
    })
  end

  defp request_save(%{assigns: %{kind: :edit_comment}} = socket) do
    PhoenixClient.request("comments", "edit", %{
      "id" => socket.assigns.record["id"],
      "content" => socket.assigns.body,
      "author" => socket.assigns.record["author"] || "Aayush"
    })
  end

  defp send_initial_state(socket) do
    kind = socket.assigns.kind

    Mob.WebView.post_message(socket, %{
      "event" => "init",
      "title" => socket.assigns.title,
      "body" => socket.assigns.body,
      "expiry" => socket.assigns.expiry,
      "show_title" => kind in [:new_bin, :edit_bin],
      "show_expiry" => kind == :new_bin,
      "heading" => editor_heading(kind),
      "body_label" => body_label(kind)
    })
  end

  defp editor_state(socket, state, message \\ nil)

  defp editor_state(%{assigns: %{web_ready: true}} = socket, state, message) do
    Mob.WebView.post_message(socket, %{
      "event" => "save_state",
      "state" => state,
      "message" => message
    })
  end

  defp editor_state(socket, _state, _message), do: socket

  defp valid?(%{assigns: %{kind: kind, body: body, title: title}}) do
    String.trim(body) != "" and (kind not in [:new_bin, :edit_bin] or String.trim(title) != "")
  end

  defp expiry_payload("hour"), do: %{"time" => 1, "unit" => "hour"}
  defp expiry_payload("week"), do: %{"time" => 7, "unit" => "day"}
  defp expiry_payload(_), do: %{"time" => 1, "unit" => "day"}

  defp expiry(value) when value in ["hour", "day", "week"], do: value
  defp expiry(_value), do: "day"

  defp editor_body(kind, _record) when kind in [:new_note, :new_bin, :reply_comment], do: ""
  defp editor_body(:edit_note, record), do: record["text"] || ""
  defp editor_body(:edit_bin, record), do: record["content"] || ""
  defp editor_body(:edit_comment, record), do: record["content"] || ""
  defp editor_body(_kind, record), do: record["content"] || record["text"] || ""

  defp editor_heading(:new_note), do: "New note"
  defp editor_heading(:edit_note), do: "Edit note"
  defp editor_heading(:new_bin), do: "New paste"
  defp editor_heading(:edit_bin), do: "Edit paste"
  defp editor_heading(:reply_comment), do: "Write a reply"
  defp editor_heading(:edit_comment), do: "Edit comment"
  defp editor_heading(_), do: "Editor"

  defp body_label(kind) when kind in [:new_note, :edit_note], do: "Note"
  defp body_label(kind) when kind in [:reply_comment, :edit_comment], do: "Comment"
  defp body_label(_), do: "Content"

  defp editor_url do
    "file://#{Bnana.App.priv_path("remote_editor/index.html")}"
  end

  defp binary(value) when is_binary(value), do: value
  defp binary(_value), do: ""
end
