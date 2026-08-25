defmodule Bnana.Repo.Migrations.CreateBlogDrafts do
  use Ecto.Migration

  def change do
    create table(:blog_drafts) do
      add(:title, :text, null: false, default: "")
      add(:body, :text, null: false, default: "")
      add(:cover_path, :text)
      add(:cover_name, :text)
      add(:status, :text, null: false, default: "wip")

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:blog_drafts, [:updated_at]))
  end
end
