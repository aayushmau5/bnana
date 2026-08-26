defmodule Bnana.MixProject do
  use Mix.Project

  def project do
    [
      app: :bnana,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      deps: deps(),
      aliases: aliases(),
      erlc_paths: ["src"],
      erlc_options: [:debug_info]
    ]
  end

  def application do
    [extra_applications: [:logger, :public_key, :ssl]]
  end

  defp deps do
    [
      {:mob, "~> 0.7"},
      {:mob_dev, "~> 0.6", only: :dev, runtime: false},
      {:ecto_sqlite3, "~> 0.18"},
      {:phoenix_socket_client, "~> 0.8.2"},
      {:castore, "~> 1.0"},
      # Code quality — Credo + ex_slop (catches AI-generated patterns
      # like blanket rescue, narrator docs, redundant Enum chains, etc).
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4.2", only: [:dev, :test], runtime: false}
    ]
  end

  # Shorthands for the common mob workflows — `mix deploy` is `mix mob.deploy`,
  # etc. Extra args pass through to the underlying task, so `mix deploy
  # --device <udid>` works as expected.
  defp aliases do
    [
      compile: [&copy_cacerts/1, "compile"],
      connect: ["mob.connect"],
      deploy: ["mob.deploy"],
      watch: ["mob.watch"],
      icon: ["mob.icon"],
      ios: ["mob.deploy --ios"],
      "ios.native": ["mob.deploy --native --ios"],
      android: ["mob.deploy --android"],
      "android.native": ["mob.deploy --native --android"]
    ]
  end

  defp copy_cacerts(_args) do
    source = Path.join(Mix.Project.deps_paths().castore, "priv/cacerts.pem")
    destination = Path.join("priv", "cacerts.pem")

    if not File.exists?(destination) or File.read!(destination) != File.read!(source) do
      File.cp!(source, destination)
    end
  end
end
