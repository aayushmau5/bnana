defmodule Bnana.Blogs do
  @moduledoc "Persistence API for local work-in-progress blog drafts."
  import Ecto.Query

  alias Bnana.{BlogDraft, Repo}

  def list_drafts do
    Repo.all(from(draft in BlogDraft, order_by: [desc: draft.updated_at, desc: draft.id]))
  end

  def get_draft!(id), do: Repo.get!(BlogDraft, id)

  def create_draft(attrs \\ %{}) do
    %BlogDraft{}
    |> BlogDraft.changeset(
      Map.merge(
        %{title: "", body: "", status: "wip", editor_mode: "edit", cursor_position: 0},
        attrs
      )
    )
    |> Repo.insert()
  end

  def update_draft(%BlogDraft{} = draft, attrs) do
    draft
    |> BlogDraft.changeset(attrs)
    |> Repo.update()
  end

  def delete_draft(%BlogDraft{} = draft), do: Repo.delete(draft)
end
