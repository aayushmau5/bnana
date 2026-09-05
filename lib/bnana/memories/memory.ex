defmodule Bnana.Memory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "memories" do
    field(:body, :string)
    field(:photo_path, :string)
    field(:memory_date, :date)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [:body, :photo_path, :memory_date])
    |> validate_required([:body, :memory_date])
    |> validate_length(:body, max: 100_000)
  end
end
