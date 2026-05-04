defmodule Taskboard.Projects.ProjectTask.Changes.CascadeCompleteDetailTasks do
  @moduledoc """
  When a main-task is explicitly completed, also completes all its detail-tasks.
  Runs as part of the :complete action.
  """
  use Ash.Resource.Change
  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, task ->
      if task.task_type == :main do
        cascade(task)
      end

      {:ok, task}
    end)
  end

  defp cascade(main_task) do
    {:ok, details} =
      Taskboard.Projects.ProjectTask
      |> Ash.Query.filter(parent_id == ^main_task.id and task_type == :detail)
      |> Ash.read(authorize?: false)

    Enum.each(details, fn detail ->
      unless detail.status in [:done, :skipped] do
        Ash.update!(detail, %{}, action: :complete, authorize?: false)
      end
    end)
  end
end
