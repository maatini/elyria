defmodule TaskboardWeb.E2E.DashboardTest do
  @moduledoc false
  use TaskboardWeb.FeatureCase, async: false

  alias Taskboard.Factory

  setup %{conn: conn} do
    user = create_user()
    {:ok, conn: log_in_user(conn, user)}
  end

  test "renders heading", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Dashboard"
  end

  test "shows open-tasks counter", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Meine Aufgaben"
  end

  test "shows overdue counter", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Überfällig"
  end

  test "shows active projects counter", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "aktive Projekte"
  end

  test "project count increases after activation", %{conn: conn} do
    template = Factory.create_template()
    context = Factory.create_context()
    Factory.activate_project(template, context)

    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "1"
  end
end
