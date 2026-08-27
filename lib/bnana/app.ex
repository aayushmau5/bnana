defmodule Bnana.App do
  @moduledoc "Application entry point for Bnana."

  use Mob.App

  @impl Mob.App
  def navigation(_platform) do
    stack(:main, root: Bnana.HomeScreen)
  end

  @impl Mob.App
  def on_start do
    Mob.Theme.set(Bnana.Theme)

    {:ok, _} = Application.ensure_all_started(:req)

    # Configure BEAM's DNS path so Req / Finch / Mint / `gen_tcp:connect/3`
    # with a hostname work on iOS without per-host setup. Flips the lookup
    # chain from the iOS-broken `:native` (inet_gethost port program) path
    # to `[:file, :dns]` and seeds Google + Cloudflare as fallback
    # nameservers. Override with `nameservers:` if you need to (corporate
    # resolver, Quad9, etc.) — see `Mob.DNS.configure_pure_beam/1`.
    #
    # For hosts that need Apple's resolver (VPN-pushed DNS, mDNS,
    # captive portals, search-domain expansion) call `Mob.DNS.resolve/1`
    # for those specific hostnames here too. Both paths compose.
    Mob.DNS.configure_pure_beam()
    Mob.Certs.load_cacerts!(priv_path("cacerts.pem"))

    {:ok, _} = Application.ensure_all_started(:ecto_sqlite3)
    {:ok, _} = Bnana.Repo.start_link()
    {:ok, _} = Bnana.PhoenixClient.start_link()

    Ecto.Migrator.with_repo(Bnana.Repo, fn repo ->
      Ecto.Migrator.run(repo, priv_path("repo/migrations"), :up, all: true)
    end)

    {:ok, _screen} = Mob.Screen.start_root(Bnana.HomeScreen)
    Bnana.DeepLinks.consume()
    Mob.Dist.ensure_started(node: :"bnana_ios@127.0.0.1", cookie: :mob_secret)
  end

  # Returns the path to the migrations directory for the current environment.
  #
  # WHY NOT Application.app_dir/2?
  #
  # Application.app_dir(app, "priv/repo/migrations") calls :code.priv_dir(app)
  # under the hood. That works in a normal `mix run` dev environment where the
  # app lives in $OTP_ROOT/lib/APP-VERSION/ebin/.
  #
  # On Android and iOS, Mob deploys .beam files to a flat -pa directory with no
  # versioned lib structure, so :code.priv_dir/1 returns {error, bad_name}.
  # Ecto.Migrator.run/3 silently finds zero migrations and logs "Migrations
  # already up" — tables are never created and any query against them crashes
  # the screen GenServer, making the screen appear frozen.
  #
  # The fix: mob_beam.c/mob_beam.m set MOB_BEAMS_DIR=beams_dir before erl_start.
  # The deployer pushes priv/ into beams_dir/priv/ and runs chmod -R 755 on it
  # (mkdir-as-root creates system:system drwxrwx--x dirs that the app process
  # can traverse but not list, breaking Path.wildcard). Here we read MOB_BEAMS_DIR
  # and pass the explicit path to Ecto.Migrator.run/4.
  def priv_path(relative_path) do
    case System.get_env("MOB_BEAMS_DIR") do
      nil -> Application.app_dir(:bnana, Path.join("priv", relative_path))
      beams_dir -> Path.join([beams_dir, "priv", relative_path])
    end
  end
end
