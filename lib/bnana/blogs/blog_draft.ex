defmodule Bnana.BlogDraft do
  use Ecto.Schema
  import Ecto.Changeset

  schema "blog_drafts" do
    field(:title, :string, default: "")
    field(:body, :string, default: "")
    field(:editor_mode, :string, default: "edit")
    field(:cursor_position, :integer, default: 0)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [:title, :body, :editor_mode, :cursor_position])
    |> validate_required([:editor_mode, :cursor_position])
    |> validate_inclusion(:editor_mode, ["edit", "preview"])
    |> validate_number(:cursor_position, greater_than_or_equal_to: 0)
  end
end
