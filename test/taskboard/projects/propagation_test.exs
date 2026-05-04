defmodule Taskboard.Projects.PropagationTest do
  use Taskboard.DataCase, async: false

  require Ash.Query

  alias Taskboard.Factory
  alias Taskboard.Projects.ProjectTask

  describe "PropagateStatusToSuccessors" do
    setup do
      template = Factory.create_template()
      chapter = Factory.create_chapter(template)
      t1_tpl = Factory.create_task(template, chapter, title: "T1", position: 1)
      t2_tpl = Factory.create_task(template, chapter, title: "T2", position: 2)
      Factory.create_task_dep(t1_tpl, t2_tpl)

      context = Factory.create_context()
      project = Factory.activate_project(template, context)

      tasks =
        ProjectTask
        |> Ash.Query.filter(project_id == ^project.id)
        |> Ash.read!(authorize?: false)

      t1 = Enum.find(tasks, &(&1.title == "T1"))
      t2 = Enum.find(tasks, &(&1.title == "T2"))

      %{t1: t1, t2: t2}
    end

    test "successor is :blocked initially", %{t2: t2} do
      assert t2.status == :blocked
    end

    test "completing predecessor unblocks successor", %{t1: t1, t2: t2} do
      assert t2.status == :blocked

      Ash.update!(t1, %{}, action: :complete, authorize?: false)

      {:ok, t2_updated} = Ash.get(ProjectTask, t2.id, authorize?: false)
      assert t2_updated.status == :open
    end

    test "skipping predecessor also unblocks successor", %{t1: t1, t2: t2} do
      assert t2.status == :blocked

      Ash.update!(t1, %{}, action: :skip, authorize?: false)

      {:ok, t2_updated} = Ash.get(ProjectTask, t2.id, authorize?: false)
      assert t2_updated.status == :open
    end

    test "completing predecessor does not unblock if other predecessor is still pending" do
      template = Factory.create_template()
      chapter = Factory.create_chapter(template)
      ta = Factory.create_task(template, chapter, title: "TA", position: 1)
      tb = Factory.create_task(template, chapter, title: "TB", position: 2)
      tc = Factory.create_task(template, chapter, title: "TC", position: 3)
      Factory.create_task_dep(ta, tc)
      Factory.create_task_dep(tb, tc)

      context = Factory.create_context()
      project = Factory.activate_project(template, context)

      tasks =
        ProjectTask
        |> Ash.Query.filter(project_id == ^project.id)
        |> Ash.read!(authorize?: false)

      pt_a = Enum.find(tasks, &(&1.title == "TA"))
      pt_c = Enum.find(tasks, &(&1.title == "TC"))

      Ash.update!(pt_a, %{}, action: :complete, authorize?: false)

      {:ok, tc_after} = Ash.get(ProjectTask, pt_c.id, authorize?: false)
      assert tc_after.status == :blocked
    end
  end
end
