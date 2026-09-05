defmodule Bnana.UIAuditTest do
  use Mob.ScreenCase, async: true

  test "all screens render native-supported trees with empty or missing content" do
    screens = [
      {Bnana.HomeScreen, %{}},
      {Bnana.BlogsScreen, %{drafts: [], pending_delete: nil}},
      {Bnana.BlogEditorScreen, %{}},
      {Bnana.RemoteEditorScreen, %{}},
      {Bnana.MemoryBookScreen, %{memories: []}},
      {Bnana.MemoryScreen, %{memory: nil, confirm_delete: false}},
      {Bnana.MemoryBookEditorScreen,
       %{keyboard_open: false, photo_source: nil, photo_action: nil, saving: false}},
      {Bnana.SavedLinksScreen, %{links: [], revealed_link_id: nil, pending_delete: nil}},
      {Bnana.LinkCaptureScreen,
       %{title: "A link", url: "https://example.com", title_status: :idle}},
      {Bnana.IncentivesScreen, %{title: "Missing link", url: "", status: {:error, :not_found}}},
      {Bnana.PhoenixScreen,
       %{connection: %{status: :needs_secret, configured?: false}, secret: ""}},
      {Bnana.AnalyticsScreen,
       %{stats: %{}, daily: [], devices: [], blogs_expanded: true, error: nil}},
      {Bnana.BinScreen, %{pastes: [], error: nil}},
      {Bnana.BinDetailScreen, %{record: %{}, confirm_delete: false}},
      {Bnana.WorkspacesScreen, %{workspaces: [], error: nil}},
      {Bnana.NotesScreen, %{workspace: %{}, notes: [], pending_delete: nil, error: nil}},
      {Bnana.CommentsScreen,
       %{blogs: [], selected_blog: nil, blog_picker_expanded: false, comments: [], error: nil}},
      {Bnana.ContactMessagesScreen, %{messages: [], error: nil}},
      {Bnana.ContactMessageScreen, %{record: %{}}}
    ]

    for {screen, assigns} <- screens do
      assert_renderable(screen.render(assigns), extra: [:icon, :canvas])
    end
  end

  test "a missing link has no retry or credential replacement actions" do
    tree =
      Bnana.IncentivesScreen.render(%{title: "Missing", url: "", status: {:error, :not_found}})

    assert text(tree) =~ "no longer exists"
    refute find(tree, :button, text: "Try again")
    refute find(tree, :button, text: "Replace token")
  end

  test "credential fields preserve typed input across renders" do
    tree =
      Bnana.IncentivesScreen.render(%{
        title: "Link",
        url: "",
        status: :needs_token,
        token: "typed"
      })

    assert find(tree, :text_field, value: "typed")

    tree =
      Bnana.PhoenixScreen.render(%{
        connection: %{status: :needs_secret, configured?: false},
        secret: "typed"
      })

    assert find(tree, :text_field, value: "typed")
  end
end
