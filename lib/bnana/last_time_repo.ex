defmodule Bnana.LastTimeRepo do
  @moduledoc "The Last time database shared with the iOS widget extension."
  use Ecto.Repo, otp_app: :bnana, adapter: Ecto.Adapters.SQLite3

  @impl true
  def init(_type, config) do
    directory = System.get_env("BNANA_WIDGET_DIR") || Bnana.Repo.data_dir()
    File.mkdir_p!(directory)

    {:ok,
     Keyword.merge(config,
       database: Path.join(directory, "last_time.db"),
       pool_size: 1,
       busy_timeout: 5_000,
       journal_mode: :wal
     )}
  end
end
