defmodule Bnana.MemoryBookFlowTest do
  use Mob.ScreenCase, async: false

  alias Bnana.{Memories, Memory, MemoryBookEditorScreen, MemoryBookScreen, MemoryScreen, Repo}

  setup_all do
    previous_data_dir = System.get_env("MOB_DATA_DIR")

    data_dir =
      Path.join(System.tmp_dir!(), "bnana_memories_#{System.unique_integer([:positive])}")

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

    {:ok, data_dir: data_dir}
  end

  setup do
    Repo.delete_all(Memory)
    :ok
  end

  test "keeps text-only and photographed memories in newest-first order", %{data_dir: data_dir} do
    source = Path.join(data_dir, "camera.jpg")
    File.write!(source, "pretend jpeg")

    assert {:ok, older} =
             Memories.create_memory(%{body: "An older day", memory_date: ~D[2026-09-02]})

    assert {:ok, newer} =
             Memories.create_memory(%{
               body: "A day worth keeping",
               memory_date: ~D[2026-09-04],
               photo_source: source
             })

    assert [^newer, ^older] = Memories.list_memories()
    assert newer.photo_path != source
    assert File.read!(newer.photo_path) == "pretend jpeg"
    assert is_nil(older.photo_path)
  end

  test "the book opens an empty composer" do
    view = mount_screen(MemoryBookScreen)

    assert_renderable(view, extra: [:icon])
    assert text(view) =~ "The first page is waiting."

    view = render_info(view, {:tap, :new_memory})
    assert navigated_to(view) == MemoryBookEditorScreen
  end

  test "shows one date beside all memories from that day" do
    assert {:ok, first} =
             Memories.create_memory(%{body: "Morning light", memory_date: ~D[2026-09-04]})

    assert {:ok, _second} =
             Memories.create_memory(%{body: "Evening walk", memory_date: ~D[2026-09-04]})

    view = mount_screen(MemoryBookScreen)

    assert [_date] = find_all(view, :text, text: "04")
    assert [_first, _second] = find_all(view, :text, text: "VIEW →")

    view = render_info(view, {:tap, {:view_memory, first.id}})
    assert navigated_to(view) == MemoryScreen
  end

  test "the composer accepts a selected photo and saves the memory", %{data_dir: data_dir} do
    source = Path.join(data_dir, "chosen.png")
    File.write!(source, "pretend png")

    view = mount_screen(MemoryBookEditorScreen)
    assert_renderable(view, extra: [:icon])
    assert find(view, :web_view)
    assert find(view, :button, text: "◎  Take a photo")

    view =
      render_info(view, {
        :webview,
        :message,
        %{"event" => "change", "body" => "A tiny memory worth keeping."}
      })

    view =
      render_info(view, {
        :photos,
        :picked,
        [%{path: source, name: "chosen.png", size: 11}]
      })

    assert assigns(view).photo_source == source
    assert find(view, :image, width: 268)
    assert find(view, :image, content_mode: "fit")

    _view = render_info(view, {:tap, :save_memory})

    assert [%Memory{body: "A tiny memory worth keeping.", photo_path: stored}] =
             Memories.list_memories()

    assert File.exists?(stored)
  end

  test "camera results attach safely and cancellation clears the in-flight state", %{
    data_dir: data_dir
  } do
    source = Path.join(data_dir, "camera.jpg")
    File.write!(source, "pretend jpeg")

    view = mount_screen(MemoryBookEditorScreen)
    view = %{view | socket: Mob.Socket.assign(view.socket, :photo_action, :camera)}
    view = render_info(view, {:camera, :cancelled})

    assert assigns(view).photo_action == nil
    assert assigns(view).photo_source == nil

    view = render_info(view, {:camera, :photo, %{path: source, width: 1200, height: 900}})

    assert assigns(view).photo_action == nil
    assert assigns(view).photo_source == source
  end

  test "the writing area hides photo actions while the keyboard is open" do
    view = mount_screen(MemoryBookEditorScreen)
    assert find(view, :button, text: "Keep this memory")

    view = render_info(view, {:webview, :message, %{"event" => "keyboard", "open" => true}})
    refute find(view, :button, text: "Keep this memory")
    refute find(view, :button, text: "◎  Take a photo")

    view = render_info(view, {:webview, :message, %{"event" => "keyboard", "open" => false}})
    assert find(view, :button, text: "Keep this memory")
  end

  test "deletes a memory and its stored photo from the reading view", %{data_dir: data_dir} do
    source = Path.join(data_dir, "delete-me.jpg")
    File.write!(source, "pretend jpeg")

    assert {:ok, memory} =
             Memories.create_memory(%{
               body: "A memory to remove",
               photo_source: source,
               memory_date: ~D[2026-09-04]
             })

    stored_photo = memory.photo_path
    view = mount_screen(MemoryScreen, %{id: memory.id})

    assert_renderable(view, extra: [:icon])
    assert find(view, :button, text: "Delete memory")

    view = render_info(view, {:tap, :delete_memory})
    assert text(view) =~ "Delete this memory and its photo?"

    view = render_info(view, {:tap, :confirm_delete})

    assert navigated_to(view) == {:pop}
    assert Memories.get_memory(memory.id) == nil
    refute File.exists?(stored_photo)
  end

  test "rejects missing and malformed photo sources instead of copying them" do
    assert {:error, :invalid_photo} =
             Memories.create_memory(%{
               body: "No ghost photos",
               photo_source: "/missing/photo.jpg"
             })

    assert {:error, :invalid_photo} =
             Memories.create_memory(%{body: "No malformed payloads", photo_source: %{path: nil}})

    assert Memories.list_memories() == []
  end
end
