defmodule Bnana.SavedLink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "saved_links" do
    field(:url, :string)
    field(:title, :string, default: "")

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:url, :title])
    |> validate_required([:url])
    |> validate_length(:url, max: 16_384)
    |> validate_length(:title, max: 500)
    |> validate_format(:url, ~r/^https?:\/\/[^\s]+$/i)
  end
end
