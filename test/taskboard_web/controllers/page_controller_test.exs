defmodule TaskboardWeb.PageControllerTest do
  use TaskboardWeb.ConnCase

  test "GET / redirects unauthenticated users to sign-in", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/sign-in"
  end
end
