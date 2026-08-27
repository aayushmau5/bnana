defmodule Bnana.LinksFlowTest do
  use Mob.ScreenCase, async: false

  alias Bnana.{DeepLinks, HomeScreen, LinkCaptureScreen, Links, Repo, SavedLink}

  setup_all do
    previous_data_dir = System.get_env("MOB_DATA_DIR")
    previous_fetch_setting = Application.get_env(:bnana, :fetch_link_titles)
    data_dir = Path.join(System.tmp_dir!(), "bnana_links_#{System.unique_integer([:positive])}")
    System.put_env("MOB_DATA_DIR", data_dir)
    Application.put_env(:bnana, :fetch_link_titles, false)

    start_supervised!(Repo)

    migrations = Application.app_dir(:bnana, "priv/repo/migrations")
    Ecto.Migrator.run(Repo, migrations, :up, all: true, log: false)

    on_exit(fn ->
      if previous_data_dir do
        System.put_env("MOB_DATA_DIR", previous_data_dir)
      else
        System.delete_env("MOB_DATA_DIR")
      end

      if is_nil(previous_fetch_setting) do
        Application.delete_env(:bnana, :fetch_link_titles)
      else
        Application.put_env(:bnana, :fetch_link_titles, previous_fetch_setting)
      end

      File.rm_rf(data_dir)
    end)

    :ok
  end

  setup do
    Repo.delete_all(SavedLink)
    :ok
  end

  test "accepts web URLs and rejects unsafe schemes" do
    assert DeepLinks.validate_url(" https://example.com/a?b=1 ") ==
             {:ok, "https://example.com/a?b=1"}

    assert DeepLinks.validate_url("javascript:alert(1)") == :error
    assert DeepLinks.validate_url("bnana://capture") == :error
    assert DeepLinks.validate_url("https://") == :error
  end

  test "extracts and cleans a page title" do
    html = "<html><head><title> Alice &amp; Bob &#8211; Home </title></head></html>"

    assert Links.title_from_html(html) == {:ok, "Alice & Bob – Home"}
    assert Links.title_from_html("<html><body>No title</body></html>") == :error
  end

  test "a stopped HTTP client returns an error instead of hanging" do
    Application.stop(:req)

    try do
      assert Links.fetch_title("https://example.com") == :error
    after
      Application.ensure_all_started(:req)
    end
  end

  test "a captured URL directly opens the capture form" do
    {:ok, screen} = Mob.Screen.start_link(HomeScreen, %{})
    Process.register(screen, :mob_screen)

    on_exit(fn ->
      if Process.alive?(screen), do: GenServer.stop(screen)
    end)

    assert :ok = DeepLinks.open("https://example.com")
    assert Mob.Screen.get_current_module(screen) == LinkCaptureScreen
    assert Mob.Screen.get_socket(screen).assigns.url == "https://example.com"

    assert Enum.map(Mob.Screen.get_nav_history(screen), &elem(&1, 0)) == [
             Bnana.SavedLinksScreen,
             HomeScreen
           ]
  end

  test "the capture form saves and pops to the links list" do
    {:ok, screen} = Mob.Screen.start_link(HomeScreen, %{})
    Process.register(screen, :mob_screen)

    on_exit(fn ->
      if Process.alive?(screen), do: GenServer.stop(screen)
    end)

    DeepLinks.open("https://example.com/article")
    assert Mob.Screen.get_socket(screen).assigns.title == "example.com"

    send(screen, {:change, :link_title, "An article"})
    send(screen, {:link_title_fetched, {:ok, "Fetched too late"}})
    assert Mob.Screen.get_socket(screen).assigns.title == "An article"
    assert Mob.Screen.get_socket(screen).assigns.title_status == :found
    send(screen, {:tap, :save_link})

    assert Mob.Screen.get_current_module(screen) == Bnana.SavedLinksScreen
    assert Enum.map(Mob.Screen.get_nav_history(screen), &elem(&1, 0)) == [HomeScreen]

    assert [%SavedLink{title: "An article", url: "https://example.com/article"}] =
             Links.list_links()
  end
end
