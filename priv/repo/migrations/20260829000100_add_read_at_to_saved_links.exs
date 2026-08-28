defmodule Bnana.Repo.Migrations.AddReadAtToSavedLinks do
  use Ecto.Migration

  def change do
    alter table(:saved_links) do
      add(:read_at, :utc_datetime_usec)
    end
  end
end
