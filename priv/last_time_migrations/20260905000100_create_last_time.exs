defmodule Bnana.LastTimeRepo.Migrations.CreateLastTime do
  use Ecto.Migration

  def change do
    create table(:last_time_items) do
      add(:name, :text, null: false)
      add(:interval_days, :integer)
      add(:pinned, :integer, null: false, default: 0)
    end

    create table(:last_time_events, primary_key: false) do
      add(:id, :text, primary_key: true)
      add(:item_id, references(:last_time_items, on_delete: :delete_all), null: false)
      add(:occurred_on, :text, null: false)
      add(:recorded_at, :bigint, null: false)
    end

    create(index(:last_time_events, [:item_id, :occurred_on]))
  end
end
