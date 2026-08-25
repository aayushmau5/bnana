defmodule Bnana.HomeScreenTest do
  use Mob.ScreenCase, async: false

  alias Bnana.HomeScreen

  test "mounts and renders a tree the native layer can draw" do
    view = mount_screen(HomeScreen)
    assert_renderable(view)
  end

  test "shows blogs as the sole product destination" do
    view = mount_screen(HomeScreen)

    assert text(view) =~ "Blogs"
    assert find(view, :button, text: "wander in  →")
    refute find(view, :button, text: "Eva")
  end

  test "opens the blogs dashboard" do
    view = HomeScreen |> mount_screen() |> render_info({:tap, :open_blogs})
    assert navigated_to(view) == Bnana.BlogsScreen
  end
end
