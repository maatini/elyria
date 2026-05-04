defmodule TaskboardWeb.PageController do
  use TaskboardWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
