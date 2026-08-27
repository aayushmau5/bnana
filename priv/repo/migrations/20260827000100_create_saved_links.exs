defmodule Bnana.Repo.Migrations.CreateSavedLinks do
  use Ecto.Migration

  def change do
    create table(:saved_links) do
      add(:url, :text, null: false)
      add(:title, :text, null: false, default: "")

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:saved_links, [:inserted_at]))
  end
end
