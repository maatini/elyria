defmodule Taskboard.Projects.ProjectTask.Changes.AutoReopenMainTask do
  @moduledoc """
  When a detail-task is reopened, reopens its parent main-task if it was done/skipped.
  Runs as part of the :reopen action.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, task ->
      if task.task_type == :detail and not is_nil(task.parent_id) do
        maybe_reopen_main(task)
      end

      {:ok, task}
    end)
  end

  defp maybe_reopen_main(detail_task) do
    with {:ok, main_task} <-
           Ash.get(Taskboard.Projects.ProjectTask, detail_task.parent_id, authorize?: false),
         true <- main_task.task_type == :main,
         true <- main_task.status in [:done, :skipped] do
      Ash.update!(main_task, %{}, action: :reopen, authorize?: false)
    else
      _ -> :ok
    end
  end
end
