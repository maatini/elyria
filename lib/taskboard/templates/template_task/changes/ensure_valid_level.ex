defmodule Taskboard.Templates.TemplateTask.Changes.EnsureValidLevel do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    level = Ash.Changeset.get_attribute(changeset, :level)
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)

    cond do
      level == 0 and not is_nil(parent_id) ->
        Ash.Changeset.add_error(changeset,
          field: :parent_id,
          message: "must be nil for chapters (level 0)"
        )

      level == 1 and is_nil(parent_id) ->
        Ash.Changeset.add_error(changeset,
          field: :parent_id,
          message: "is required for tasks (level 1)"
        )

      level == 2 and is_nil(parent_id) ->
        Ash.Changeset.add_error(changeset,
          field: :parent_id,
          message: "is required for detail tasks (level 2)"
        )

      true ->
        changeset
    end
  end
end
