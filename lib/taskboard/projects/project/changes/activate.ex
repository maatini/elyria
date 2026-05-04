defmodule Taskboard.Projects.Project.Changes.Activate do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    template_id = Ash.Changeset.get_argument(changeset, :template_id)
    reference_date = Ash.Changeset.get_argument(changeset, :reference_date)
    name_arg = Ash.Changeset.get_argument(changeset, :name)
    context_id = Ash.Changeset.get_argument(changeset, :context_id)
    project_type_id = Ash.Changeset.get_argument(changeset, :project_type_id)

    case Ash.get(Taskboard.Templates.Template, template_id, authorize?: false) do
      {:ok, template} ->
        effective_name =
          name_arg || "#{template.name} – #{Calendar.strftime(reference_date, "%d.%m.%Y")}"

        changeset
        |> Ash.Changeset.force_change_attribute(:name, effective_name)
        |> Ash.Changeset.force_change_attribute(:reference_date, reference_date)
        |> Ash.Changeset.force_change_attribute(:template_id, template_id)
        |> Ash.Changeset.force_change_attribute(:context_id, context_id)
        |> Ash.Changeset.force_change_attribute(:project_type_id, project_type_id)
        |> Ash.Changeset.force_change_attribute(:activated_at, DateTime.utc_now())
        |> Ash.Changeset.after_action(&after_activate(&1, &2, template_id, reference_date))

      {:error, _} ->
        Ash.Changeset.add_error(changeset,
          field: :template_id,
          message: "Template nicht gefunden"
        )
    end
  end

  defp after_activate(_changeset, project, template_id, reference_date) do
    with {:ok, {tasks, deps}} <- load_template_data(template_id) do
      create_tasks_and_deps(project, tasks, deps, reference_date)
    end
  end

  defp load_template_data(template_id) do
    with {:ok, tasks} <-
           Taskboard.Templates.TemplateTask
           |> Ash.Query.filter(template_id == ^template_id)
           |> Ash.read(authorize?: false),
         task_ids = Enum.map(tasks, & &1.id),
         {:ok, deps} <-
           Taskboard.Templates.TemplateTaskDependency
           |> Ash.Query.filter(predecessor_id in ^task_ids)
           |> Ash.read(authorize?: false) do
      {:ok, {tasks, deps}}
    end
  end

  defp create_tasks_and_deps(project, all_tasks, all_deps, reference_date) do
    tasks_with_incoming_deps = MapSet.new(all_deps, & &1.successor_id)

    root_tasks =
      all_tasks
      |> Enum.filter(&is_nil(&1.parent_id))
      |> Enum.sort_by(& &1.position)

    task_id_map =
      Enum.reduce(root_tasks, %{}, fn task, acc ->
        status = initial_status(task.id, tasks_with_incoming_deps)

        {:ok, pt} =
          Ash.create(
            Taskboard.Projects.ProjectTask,
            task_attrs(task, project.id, nil, reference_date, status),
            authorize?: false
          )

        acc = Map.put(acc, task.id, pt.id)

        task.id
        |> children_of(all_tasks)
        |> Enum.reduce(acc, fn child, child_acc ->
          child_status = initial_status(child.id, tasks_with_incoming_deps)

          {:ok, child_pt} =
            Ash.create(
              Taskboard.Projects.ProjectTask,
              task_attrs(child, project.id, pt.id, reference_date, child_status),
              authorize?: false
            )

          Map.put(child_acc, child.id, child_pt.id)
        end)
      end)

    Enum.each(all_deps, fn dep ->
      pred = Map.get(task_id_map, dep.predecessor_id)
      succ = Map.get(task_id_map, dep.successor_id)

      if pred && succ do
        Ash.create!(
          Taskboard.Projects.ProjectTaskDependency,
          %{predecessor_id: pred, successor_id: succ, type: dep.type, lag_days: dep.lag_days},
          authorize?: false
        )
      end
    end)

    {:ok, project}
  end

  defp initial_status(task_id, tasks_with_incoming_deps) do
    if MapSet.member?(tasks_with_incoming_deps, task_id), do: :blocked, else: :open
  end

  defp children_of(parent_id, all_tasks) do
    all_tasks
    |> Enum.filter(&(&1.parent_id == parent_id))
    |> Enum.sort_by(& &1.position)
  end

  defp task_attrs(task, project_id, parent_id, reference_date, status) do
    start_date = Date.add(reference_date, task.start_offset_days || 0)
    end_date = Date.add(reference_date, task.end_offset_days || 7)

    warning_date =
      case task.warning_offset_days do
        nil -> nil
        days -> Date.add(end_date, -days)
      end

    %{
      title: task.title,
      description: task.description,
      level: task.level,
      position: task.position,
      start_date: start_date,
      end_date: end_date,
      warning_date: warning_date,
      status: status,
      template_task_id: task.id,
      project_id: project_id,
      parent_id: parent_id,
      assigned_group_id: task.assigned_group_id,
      custom_field_values: task.custom_field_defaults || %{}
    }
  end
end
