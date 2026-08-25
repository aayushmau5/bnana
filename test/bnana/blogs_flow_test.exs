defmodule Bnana.BlogsFlowTest do
  use Mob.ScreenCase, async: false

  alias Bnana.{BlogEditorScreen, Blogs, BlogsScreen, Repo}

  setup_all do
    previous_data_dir = System.get_env("MOB_DATA_DIR")
    data_dir = Path.join(System.tmp_dir!(), "bnana_blogs_#{System.unique_integer([:positive])}")
    System.put_env("MOB_DATA_DIR", data_dir)

    start_supervised!(Repo)

    migrations = Application.app_dir(:bnana, "priv/repo/migrations")
    Ecto.Migrator.run(Repo, migrations, :up, all: true, log: false)

    on_exit(fn ->
      if previous_data_dir do
        System.put_env("MOB_DATA_DIR", previous_data_dir)
      else
        System.delete_env("MOB_DATA_DIR")
      end

      File.rm_rf(data_dir)
    end)

    :ok
  end

  setup do
    Repo.delete_all(Bnana.BlogDraft)
    :ok
  end

  test "creates, updates, and lists drafts by most recent edit" do
    assert {:ok, first} = Blogs.create_draft()
    assert {:ok, second} = Blogs.create_draft(%{title: "Second thought"})
    assert {:ok, first} = Blogs.update_draft(first, %{title: "First thought", body: "A fragment"})

    assert [most_recent | _] = Blogs.list_drafts()
    assert most_recent.id == first.id
    assert Blogs.get_draft!(second.id).title == "Second thought"
  end

  test "dashboard creates a draft and opens its editor" do
    view = mount_screen(BlogsScreen)
    assert_renderable(view)
    assert text(view) =~ "No wandering thoughts yet"

    view = render_info(view, {:tap, :create_draft})

    assert navigated_to(view) == BlogEditorScreen
    assert [_draft] = Blogs.list_drafts()
  end

  test "dashboard deletes empty and written drafts after confirmation" do
    {:ok, empty_draft} = Blogs.create_draft()
    {:ok, written_draft} = Blogs.create_draft(%{title: "Keep moving", body: "Until deleted."})

    view = mount_screen(BlogsScreen)
    view = render_info(view, {:tap, {:delete_draft, empty_draft.id}})
    assert assigns(view).pending_delete == empty_draft.id
    assert text(view) =~ "Delete this draft?"
    view = render_info(view, {:tap, {:confirm_delete, empty_draft.id}})

    assert_raise Ecto.NoResultsError, fn -> Blogs.get_draft!(empty_draft.id) end

    view
    |> render_info({:tap, {:delete_draft, written_draft.id}})
    |> render_info({:tap, {:confirm_delete, written_draft.id}})

    assert Blogs.list_drafts() == []
  end

  test "editor debounces a change and persists the resumed position" do
    {:ok, draft} = Blogs.create_draft()
    view = mount_screen(BlogEditorScreen, %{draft_id: draft.id})

    assert_renderable(view)
    assert find(view, :web_view)

    view =
      render_info(view, {
        :webview,
        :message,
        %{
          "event" => "change",
          "title" => "Fragments from the road",
          "body" => "Written between places.",
          "cursor" => 9,
          "mode" => "preview"
        }
      })

    assert assigns(view).dirty
    token = assigns(view).save_token
    view = render_info(view, {:persist_draft, token})

    refute assigns(view).dirty
    saved = Blogs.get_draft!(draft.id)
    assert saved.title == "Fragments from the road"
    assert saved.body == "Written between places."
    assert saved.cursor_position == 9
    assert saved.editor_mode == "preview"
  end
end
