defmodule Taskboard.Projects.ProjectTask.Changes.PropagateStatusToSuccessors do
  use Ash.Resource.Change
  require Ash.Query

  @terminal_states [:done, :skipped]

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, task ->
      if task.status in @terminal_states do
        propagate(task)
      end

      {:ok, task}
    end)
  end

  defp propagate(task) do
    {:ok, outgoing} =
      Taskboard.Projects.ProjectTaskDependency
      |> Ash.Query.filter(predecessor_id == ^task.id)
      |> Ash.read(authorize?: false)

    Enum.each(outgoing, fn dep -> maybe_unblock(dep.successor_id) end)
  end

  defp maybe_unblock(successor_id) do
    with {:ok, successor} <-
           Ash.get(Taskboard.Projects.ProjectTask, successor_id, authorize?: false),
         true <- successor.status == :blocked,
         {:ok, incoming} <-
           Taskboard.Projects.ProjectTaskDependency
           |> Ash.Query.filter(successor_id == ^successor_id)
           |> Ash.read(authorize?: false),
         predecessor_ids = Enum.map(incoming, & &1.predecessor_id),
         {:ok, predecessors} <-
           Taskboard.Projects.ProjectTask
           |> Ash.Query.filter(id in ^predecessor_ids)
           |> Ash.read(authorize?: false),
         true <- Enum.all?(predecessors, &(&1.status in @terminal_states)) do
      Ash.update!(successor, %{}, action: :unblock, authorize?: false)
    else
      _ -> :ok
    end
  end
end
