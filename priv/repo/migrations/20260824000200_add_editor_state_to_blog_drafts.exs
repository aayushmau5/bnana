defmodule Bnana.Repo.Migrations.AddEditorStateToBlogDrafts do
  use Ecto.Migration

  def change do
    alter table(:blog_drafts) do
      add(:editor_mode, :text, null: false, default: "edit")
      add(:cursor_position, :integer, null: false, default: 0)
    end
  end
end
