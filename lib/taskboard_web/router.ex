defmodule TaskboardWeb.Router do
  use TaskboardWeb, :router
  use AshAuthentication.Phoenix.Router
  import AshAdmin.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TaskboardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  scope "/", TaskboardWeb do
    pipe_through :browser

    get "/", PageController, :home

    sign_in_route register_path: "/register", reset_path: "/reset", auth_routes_prefix: "/auth"
    sign_out_route AuthController
    auth_routes AuthController, Taskboard.Accounts.User, path: "/auth"
    reset_route []
  end

  scope "/", TaskboardWeb do
    pipe_through [:browser, :require_auth]

    ash_authentication_live_session :authenticated_routes do
      live "/dashboard", DashboardLive, :index
      live "/my-tasks", MyTasksLive, :index
      live "/projects", ProjectsLive, :index
      live "/projects/:id/gantt", ProjectGanttLive, :index
      live "/templates", TemplatesLive, :index
    end
  end

  scope "/" do
    pipe_through [:browser, :require_auth]
    ash_admin "/admin"
  end

  if Application.compile_env(:taskboard, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TaskboardWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Bitte zuerst anmelden.")
      |> Phoenix.Controller.redirect(to: "/sign-in")
      |> Plug.Conn.halt()
    end
  end
end
