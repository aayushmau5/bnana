defmodule Bnana.CommentsScreen do
  @moduledoc "Native comment moderation and reply screen."

  use Mob.Screen

  alias Bnana.{PhoenixClient, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    PhoenixClient.subscribe()
    PhoenixClient.request("stats", "get-all")

    {:ok,
     socket
     |> Mob.Socket.assign(:blogs, nil)
     |> Mob.Socket.assign(:selected_blog, nil)
     |> Mob.Socket.assign(:blog_picker_expanded, false)
     |> Mob.Socket.assign(:comments, nil)
     |> Mob.Socket.assign(:pending_delete, nil)
     |> Mob.Socket.assign(:error, nil)}
  end

  def render(assigns) do
    picker = blog_picker(assigns.blogs, assigns.selected_blog, assigns.blog_picker_expanded)
    comments = comments_content(assigns)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Comments")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="comments_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {RemoteUI.intro("Conversations in the margins.", "Choose a blog, review its threads, and reply or moderate in place.")}
            <Spacer size={20} />
            {picker}
            <Spacer size={20} />
            {comments}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, {:select_blog, slug}}, socket) do
    load_comments(slug)

    {:noreply,
     socket
     |> Mob.Socket.assign(:selected_blog, slug)
     |> Mob.Socket.assign(:blog_picker_expanded, false)
     |> Mob.Socket.assign(:comments, nil)
     |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:tap, :toggle_blog_picker}, socket) do
    {:noreply,
     Mob.Socket.assign(
       socket,
       :blog_picker_expanded,
       !socket.assigns.blog_picker_expanded
     )}
  end

  def handle_info({:tap, {:reply_comment, id}}, socket) do
    params = %{kind: :reply_comment, blog_slug: socket.assigns.selected_blog, parent_id: id}
    {:noreply, Mob.Socket.push_screen(socket, Bnana.RemoteEditorScreen, params)}
  end

  def handle_info({:tap, {:edit_comment, id}}, socket) do
    case find_comment(socket.assigns.comments || [], id) do
      nil ->
        {:noreply, socket}

      comment ->
        params = %{kind: :edit_comment, blog_slug: socket.assigns.selected_blog, record: comment}
        {:noreply, Mob.Socket.push_screen(socket, Bnana.RemoteEditorScreen, params)}
    end
  end

  def handle_info({:tap, {:delete_comment, id}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :pending_delete, id)}
  end

  def handle_info({:tap, :cancel_delete}, socket) do
    {:noreply, Mob.Socket.assign(socket, :pending_delete, nil)}
  end

  def handle_info({:tap, {:confirm_delete, id}}, socket) do
    PhoenixClient.request("comments", "delete", %{"id" => id})
    {:noreply, socket}
  end

  def handle_info({:phoenix_reply, _ref, "stats", "get-all", {:ok, stats}}, socket) do
    blogs =
      (stats["blogs"] || [])
      |> Enum.map(&normalize_blog_slug(&1["slug"]))
      |> Enum.reject(&is_nil/1)

    selected = socket.assigns.selected_blog || List.first(blogs)
    if selected, do: load_comments(selected)

    {:noreply,
     socket
     |> Mob.Socket.assign(:blogs, blogs)
     |> Mob.Socket.assign(:selected_blog, selected)}
  end

  def handle_info({:phoenix_reply, _ref, "comments", "get-all", {:ok, comments}}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:comments, comments) |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:phoenix_reply, _ref, "comments", "delete", {:ok, _data}}, socket) do
    load_comments(socket.assigns.selected_blog)

    {:noreply,
     socket
     |> Mob.Socket.assign(:pending_delete, nil)
     |> Mob.Alert.toast("Comment deleted")}
  end

  def handle_info({:phoenix_reply, _ref, event, _action, {:error, reason}}, socket)
      when event in ["stats", "comments"] do
    {:noreply, Mob.Socket.assign(socket, :error, "Comments request failed: #{inspect(reason)}")}
  end

  def handle_info({:phoenix_event, "comment-" <> _type, %{"blog_slug" => slug}}, socket) do
    if slug == socket.assigns.selected_blog, do: load_comments(slug)
    {:noreply, socket}
  end

  def handle_info({:phoenix_status, %{status: :connected}}, socket) do
    if socket.assigns.selected_blog do
      load_comments(socket.assigns.selected_blog)
    else
      PhoenixClient.request("stats", "get-all")
    end

    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def terminate(_reason, _socket) do
    PhoenixClient.unsubscribe()
    :ok
  end

  defp load_comments(nil), do: :ok

  defp load_comments(slug) do
    PhoenixClient.request("comments", "get-all", %{"blog_slug" => slug})
  end

  defp normalize_blog_slug(nil), do: nil
  defp normalize_blog_slug(slug), do: String.replace_prefix(slug, "blog:", "")

  defp blog_picker(nil, _selected, _expanded?), do: RemoteUI.loading("Finding blogs…")

  defp blog_picker([], _selected, _expanded?),
    do: RemoteUI.error("No blogs are available for comment moderation.")

  defp blog_picker(blogs, selected, expanded?) do
    buttons =
      if expanded? do
        blogs
        |> Enum.map(&blog_button(&1, &1 == selected))
        |> Enum.intersperse(~MOB(<Spacer size={6} />))
      else
        []
      end

    selected_label = selected || "Choose a blog"
    toggle_copy = if expanded?, do: "Tap to hide the blog list", else: "Tap to change the blog"
    gap = if expanded?, do: ~MOB(<Spacer size={8} />), else: []

    ~MOB"""
    <Column fill_width={true}>
      {RemoteUI.eyebrow("Blog")}
      <Spacer size={8} />
      {RemoteUI.disclosure(selected_label, toggle_copy, expanded?, :toggle_blog_picker)}
      {gap}
      {buttons}
    </Column>
    """
  end

  defp blog_button(slug, selected?) do
    tap = {self(), {:select_blog, slug}}
    background = if selected?, do: :primary, else: :surface
    color = if selected?, do: :on_primary, else: :on_surface
    font = @ui_font

    ~MOB(<Button
  text={slug}
  font={font}
  text_size={:sm}
  background={background}
  text_color={color}
  on_tap={tap}
/>)
  end

  defp comments_content(%{error: error}) when is_binary(error), do: RemoteUI.error(error)
  defp comments_content(%{selected_blog: nil}), do: []
  defp comments_content(%{comments: nil}), do: RemoteUI.loading("Loading conversation…")

  defp comments_content(%{comments: []}) do
    font = @display_font
    ~MOB(<Text
  text="No comments on this blog."
  text_size={:lg}
  font={font}
  text_color={:muted}
  text_align="center"
/>)
  end

  defp comments_content(assigns) do
    cards =
      assigns.comments
      |> flatten_comments()
      |> Enum.map(fn {comment, depth} ->
        comment_card(comment, depth, assigns.pending_delete)
      end)
      |> Enum.intersperse(~MOB(<Spacer size={10} />))

    ~MOB(<Column fill_width={true}>
  {cards}
</Column>)
  end

  defp flatten_comments(comments, depth \\ 0) do
    Enum.flat_map(comments, fn comment ->
      [{comment, depth} | flatten_comments(comment["replies"] || [], depth + 1)]
    end)
  end

  defp find_comment(comments, id) do
    Enum.find_value(comments, fn comment ->
      if comment["id"] == id, do: comment, else: find_comment(comment["replies"] || [], id)
    end)
  end

  defp comment_card(comment, depth, pending_delete) do
    author = String.duplicate("↳ ", depth) <> (comment["author"] || "Anonymous")
    content = comment["content"] || ""
    timestamp = RemoteUI.short_time(comment["updated_at"] || comment["inserted_at"])

    confirmation =
      if pending_delete == comment["id"], do: delete_confirmation(comment["id"]), else: []

    border = if depth > 0, do: :primary, else: :border
    display_font = @display_font
    ui_font = @ui_font

    ~MOB"""
    <Box
      background={:surface}
      border_color={border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_md}
      fill_width={true}
    >
      <Column fill_width={true}>
        <Text
          text={author}
          text_size={:base}
          font={display_font}
          font_weight="bold"
          text_color={:on_surface}
        />
        <Text
          text={timestamp}
          text_size={:xs}
          font={ui_font}
          text_color={:secondary}
          padding_top={:space_xs}
        />
        <Text
          text={content}
          text_size={:sm}
          font={display_font}
          text_color={:on_surface}
          line_height={1.45}
          padding_top={:space_sm}
        />
        <Spacer size={12} />
        <Row fill_width={true}>
          {small_button("Reply", {:reply_comment, comment["id"]}, :surface_raised, :primary)}
          <Spacer size={6} />
          {small_button("Edit", {:edit_comment, comment["id"]}, :surface_raised, :secondary)}
          <Spacer size={6} />
          {small_button("Delete", {:delete_comment, comment["id"]}, :surface, :error)}
        </Row>
        {confirmation}
      </Column>
    </Box>
    """
  end

  defp delete_confirmation(id) do
    font = @ui_font

    ~MOB"""
    <Column fill_width={true}>
      <Spacer size={12} />
      <Text
        text="Delete this comment and its replies?"
        text_size={:sm}
        font={font}
        text_color={:error}
      />
      <Spacer size={8} />
      <Row fill_width={true}>
        {small_button("Keep", :cancel_delete, :surface_raised, :on_surface)}
        <Spacer size={8} />
        {small_button("Delete", {:confirm_delete, id}, :error, :on_error)}
      </Row>
    </Column>
    """
  end

  defp small_button(label, tag, background, color) do
    tap = {self(), tag}
    font = @ui_font
    ~MOB(<Button
  text={label}
  font={font}
  text_size={:xs}
  background={background}
  text_color={color}
  weight={1}
  on_tap={tap}
/>)
  end
end
