defmodule Taskboard.Projects.ProjectTask.Changes.SyncMainTaskStatus do
  @moduledoc """
  After a detail-task status change, syncs the parent main-task:
  - ALL details done/skipped  → auto-complete main-task
  - ANY detail in_progress and main is open → start main-task
  """
  use Ash.Resource.Change
  require Ash.Query

  @terminal [:done, :skipped]

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, task ->
      if task.task_type == :detail and not is_nil(task.parent_id) do
        sync(task)
      end

      {:ok, task}
    end)
  end

  defp sync(detail_task) do
    with {:ok, main_task} <-
           Ash.get(Taskboard.Projects.ProjectTask, detail_task.parent_id, authorize?: false),
         true <- main_task.task_type == :main,
         {:ok, siblings} <- load_siblings(detail_task.parent_id) do
      apply_status(main_task, siblings)
    else
      _ -> :ok
    end
  end

  defp load_siblings(parent_id) do
    Taskboard.Projects.ProjectTask
    |> Ash.Query.filter(parent_id == ^parent_id and task_type == :detail)
    |> Ash.read(authorize?: false)
  end

  defp apply_status(main_task, siblings) do
    cond do
      # Alle Details erledigt → Haupt-Task auto-abschließen
      main_task.status not in @terminal and
          Enum.all?(siblings, &(&1.status in @terminal)) ->
        Ash.update!(main_task, %{}, action: :complete, authorize?: false)

      # Mindestens ein Detail in Arbeit und Haupt-Task noch offen → starten
      main_task.status == :open and
          Enum.any?(siblings, &(&1.status == :in_progress)) ->
        Ash.update!(main_task, %{}, action: :start, authorize?: false)

      true ->
        :ok
    end
  end
end
