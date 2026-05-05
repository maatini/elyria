defmodule TaskboardWeb.E2E.ProjectsTest do
  @moduledoc false
  use TaskboardWeb.FeatureCase, async: false

  alias Taskboard.Factory

  setup %{conn: conn} do
    user = create_user()
    {:ok, conn: log_in_user(conn, user)}
  end

  test "renders projects page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/projects")
    assert html =~ "Projekte"
  end

  test "shows project name in list", %{conn: conn} do
    template = Factory.create_template(name: "E2E Vorlage")
    context = Factory.create_context(name: "E2E Kontext")
    Factory.activate_project(template, context, %{name: "E2E Testprojekt"})

    {:ok, _view, html} = live(conn, ~p"/projects")
    assert html =~ "E2E Testprojekt"
  end

  test "gantt page renders for a project", %{conn: conn} do
    template = Factory.create_template()
    context = Factory.create_context()
    project = Factory.activate_project(template, context)

    {:ok, _view, html} = live(conn, ~p"/projects/#{project.id}/gantt")
    assert html =~ project.name
  end

  test "milestones page renders for a project", %{conn: conn} do
    template = Factory.create_template()
    context = Factory.create_context()
    project = Factory.activate_project(template, context)

    {:ok, _view, html} = live(conn, ~p"/projects/#{project.id}/milestones")
    assert html =~ "Meilenstein"
  end
end
