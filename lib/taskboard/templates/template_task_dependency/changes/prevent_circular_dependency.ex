defmodule Taskboard.Templates.TemplateTaskDependency.Changes.PreventCircularDependency do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    predecessor_id = Ash.Changeset.get_attribute(changeset, :predecessor_id)
    successor_id = Ash.Changeset.get_attribute(changeset, :successor_id)

    cond do
      is_nil(predecessor_id) or is_nil(successor_id) ->
        changeset

      predecessor_id == successor_id ->
        Ash.Changeset.add_error(changeset,
          field: :successor_id,
          message: "cannot depend on itself"
        )

      true ->
        changeset
    end
  end
end
