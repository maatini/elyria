defmodule Taskboard.Projects.ActivationTest do
  use Taskboard.DataCase, async: false

  require Ash.Query

  alias Taskboard.Factory
  alias Taskboard.Projects.{ProjectTask, ProjectTaskDependency}

  describe "Project.activate/1" do
    test "creates project with tasks from template" do
      template = Factory.create_template(name: "Eröffnungs-Vorlage")
      chapter = Factory.create_chapter(template, title: "Phase 1", position: 1)
      _task1 = Factory.create_task(template, chapter, title: "T1", position: 1)
      _task2 = Factory.create_task(template, chapter, title: "T2", position: 2)
      context = Factory.create_context()

      project = Factory.activate_project(template, context)

      assert project.name == "Eröffnungs-Vorlage – 01.06.2026"
      assert project.reference_date == ~D[2026-06-01]
      assert project.template_id == template.id

      tasks = load_project_tasks(project.id)
      assert length(tasks) == 3
    end

    test "uses provided name instead of generated one" do
      template = Factory.create_template()
      _chapter = Factory.create_chapter(template)
      context = Factory.create_context()

      project = Factory.activate_project(template, context, %{name: "Mein Projekt"})

      assert project.name == "Mein Projekt"
    end

    test "computes absolute dates from reference_date and offsets" do
      template = Factory.create_template()
      chapter = Factory.create_chapter(template)

      Factory.create_task(template, chapter,
        title: "Aufgabe A",
        start_offset_days: 5,
        end_offset_days: 10
      )

      context = Factory.create_context()
      ref = ~D[2026-06-01]
      project = Factory.activate_project(template, context, %{reference_date: ref})

      tasks = load_project_tasks(project.id)
      task_a = Enum.find(tasks, &(&1.title == "Aufgabe A"))

      assert task_a.start_date == ~D[2026-06-06]
      assert task_a.end_date == ~D[2026-06-11]
    end

    test "tasks with incoming deps start as :blocked, others as :open" do
      template = Factory.create_template()
      chapter = Factory.create_chapter(template)
      t1 = Factory.create_task(template, chapter, title: "T1", position: 1)
      t2 = Factory.create_task(template, chapter, title: "T2", position: 2)
      Factory.create_task_dep(t1, t2)

      context = Factory.create_context()
      project = Factory.activate_project(template, context)

      tasks = load_project_tasks(project.id)
      pt1 = Enum.find(tasks, &(&1.title == "T1"))
      pt2 = Enum.find(tasks, &(&1.title == "T2"))

      assert pt1.status == :open
      assert pt2.status == :blocked
    end

    test "creates ProjectTaskDependency records mapping template deps to project tasks" do
      template = Factory.create_template()
      chapter = Factory.create_chapter(template)
      t1 = Factory.create_task(template, chapter, title: "T1", position: 1)
      t2 = Factory.create_task(template, chapter, title: "T2", position: 2)
      Factory.create_task_dep(t1, t2)

      context = Factory.create_context()
      project = Factory.activate_project(template, context)

      deps = load_project_task_deps(project.id)
      assert length(deps) == 1

      [dep] = deps
      tasks = load_project_tasks(project.id)
      pt1 = Enum.find(tasks, &(&1.title == "T1"))
      pt2 = Enum.find(tasks, &(&1.title == "T2"))

      assert dep.predecessor_id == pt1.id
      assert dep.successor_id == pt2.id
    end

    test "template with no tasks creates empty project" do
      template = Factory.create_template()
      context = Factory.create_context()

      project = Factory.activate_project(template, context)

      tasks = load_project_tasks(project.id)
      assert tasks == []
    end
  end

  defp load_project_tasks(project_id) do
    ProjectTask
    |> Ash.Query.filter(project_id == ^project_id)
    |> Ash.read!(authorize?: false)
  end

  defp load_project_task_deps(project_id) do
    task_ids =
      ProjectTask
      |> Ash.Query.filter(project_id == ^project_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    ProjectTaskDependency
    |> Ash.Query.filter(predecessor_id in ^task_ids)
    |> Ash.read!(authorize?: false)
  end
end
