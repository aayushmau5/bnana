defmodule Bnana.Repo.Migrations.CreateBlogDrafts do
  use Ecto.Migration

  def change do
    create table(:blog_drafts) do
      add(:title, :text, null: false, default: "")
      add(:body, :text, null: false, default: "")

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:blog_drafts, [:updated_at]))
  end
end
