defmodule Bnana.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories) do
      add(:body, :text, null: false)
      add(:photo_path, :text)
      add(:memory_date, :date, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:memories, [:memory_date]))
  end
end
