defmodule TaskboardWeb.E2E.MyTasksTest do
  @moduledoc false
  use TaskboardWeb.FeatureCase, async: false

  alias Taskboard.Factory

  setup %{conn: conn} do
    user = create_user()
    {:ok, conn: log_in_user(conn, user), user: user}
  end

  test "renders my-tasks page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/my-tasks")
    assert html =~ "Meine Aufgaben"
  end

  test "shows zero tasks when user has no group assignments", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/my-tasks")
    assert html =~ "0"
  end

  test "shows task assigned to user's group", %{conn: conn, user: user} do
    group = Factory.create_group(name: "E2E Gruppe")
    Factory.create_membership(group, user)

    template = Factory.create_template()
    chapter = Factory.create_chapter(template)
    Factory.create_task(template, chapter, title: "E2E Aufgabe", assigned_group_id: group.id)

    context = Factory.create_context()
    Factory.activate_project(template, context)

    {:ok, _view, html} = live(conn, ~p"/my-tasks")
    assert html =~ "E2E Aufgabe"
  end

  test "search filters tasks by title", %{conn: conn, user: user} do
    group = Factory.create_group()
    Factory.create_membership(group, user)

    template = Factory.create_template()
    chapter = Factory.create_chapter(template)
    Factory.create_task(template, chapter, title: "Suchbarer Task", assigned_group_id: group.id)

    Factory.create_task(template, chapter,
      title: "Anderer Task",
      position: 2,
      assigned_group_id: group.id
    )

    context = Factory.create_context()
    Factory.activate_project(template, context)

    {:ok, view, _html} = live(conn, ~p"/my-tasks")

    html = view |> element("input[name='search']") |> render_change(%{search: "Suchbar"})

    assert html =~ "Suchbarer Task"
    refute html =~ "Anderer Task"
  end
end
