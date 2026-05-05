defmodule TaskboardWeb.E2E.AuthTest do
  @moduledoc false
  use TaskboardWeb.FeatureCase, async: false

  describe "unauthenticated access" do
    test "GET / redirects to sign-in", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/sign-in"
    end

    test "/dashboard redirects to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
      assert path =~ "sign-in"
    end

    test "/my-tasks redirects to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/my-tasks")
      assert path =~ "sign-in"
    end

    test "/projects redirects to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/projects")
      assert path =~ "sign-in"
    end
  end

  describe "authenticated access" do
    test "logged-in user can access dashboard", %{conn: conn} do
      user = create_user()
      conn = log_in_user(conn, user)
      assert {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Dashboard"
    end

    test "logged-in user can access projects", %{conn: conn} do
      user = create_user()
      conn = log_in_user(conn, user)
      assert {:ok, _view, html} = live(conn, ~p"/projects")
      assert html =~ "Projekte"
    end

    test "logged-in user can access my-tasks", %{conn: conn} do
      user = create_user()
      conn = log_in_user(conn, user)
      assert {:ok, _view, html} = live(conn, ~p"/my-tasks")
      assert html =~ "Meine Aufgaben"
    end
  end
end
