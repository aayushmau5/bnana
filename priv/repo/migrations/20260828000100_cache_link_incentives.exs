defmodule Bnana.Repo.Migrations.CacheLinkIncentives do
  use Ecto.Migration

  def change do
    alter table(:saved_links) do
      add(:incentives, :map)
      add(:incentives_fetched_at, :utc_datetime_usec)
    end
  end
end
