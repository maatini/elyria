defmodule TaskboardWeb.DashboardLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    stats = load_stats(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:stats, stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-5xl mx-auto">
      <div class="mb-8">
        <h1 class="text-2xl font-bold">Dashboard</h1>
        <p class="text-base-content/60 mt-1">Willkommen, <%= @current_user.email %></p>
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div class="stat bg-base-200 rounded-box">
          <div class="stat-title text-xs">Meine Aufgaben</div>
          <div class="stat-value text-2xl text-primary"><%= @stats.my_tasks %></div>
          <div class="stat-desc">offen / in Arbeit</div>
        </div>
        <div class="stat bg-base-200 rounded-box">
          <div class="stat-title text-xs">Überfällig</div>
          <div class={["stat-value text-2xl", @stats.overdue > 0 && "text-error" || "text-success"]}>
            <%= @stats.overdue %>
          </div>
          <div class="stat-desc">Aufgaben</div>
        </div>
        <div class="stat bg-base-200 rounded-box">
          <div class="stat-title text-xs">Aktive Projekte</div>
          <div class="stat-value text-2xl"><%= @stats.active_projects %></div>
          <div class="stat-desc">gesamt</div>
        </div>
        <div class="stat bg-base-200 rounded-box">
          <div class="stat-title text-xs">Vorlagen</div>
          <div class="stat-value text-2xl"><%= @stats.templates %></div>
          <div class="stat-desc">aktive</div>
        </div>
      </div>

      <div class="grid lg:grid-cols-2 gap-4">
        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title text-base">Schnellzugriff</h2>
            <div class="flex flex-col gap-2 mt-2">
              <.link navigate={~p"/my-tasks"} class="btn btn-ghost justify-start gap-3">
                <.icon name="hero-clipboard-document-check" class="size-5 text-primary" />
                Meine Aufgaben
              </.link>
              <.link navigate={~p"/projects"} class="btn btn-ghost justify-start gap-3">
                <.icon name="hero-folder-open" class="size-5 text-secondary" />
                Alle Projekte
              </.link>
              <.link navigate={~p"/templates"} class="btn btn-ghost justify-start gap-3">
                <.icon name="hero-document-duplicate" class="size-5 text-accent" />
                Vorlagen verwalten
              </.link>
              <.link navigate={~p"/admin"} class="btn btn-ghost justify-start gap-3">
                <.icon name="hero-cog-6-tooth" class="size-5 text-neutral" />
                Admin-Bereich
              </.link>
            </div>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title text-base">Aktionen</h2>
            <p class="text-sm text-base-content/60 mt-1">
              Neue Projekte können über den Admin-Bereich oder die API aus Vorlagen aktiviert werden.
            </p>
            <div class="card-actions mt-4">
              <.link navigate={~p"/admin"} class="btn btn-primary btn-sm">
                Admin öffnen
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_stats(current_user) do
    my_tasks =
      try do
        Taskboard.Projects.ProjectTask
        |> Ash.Query.for_read(:my_tasks, %{}, actor: current_user)
        |> Ash.read!()
      rescue
        _ -> []
      end

    overdue = Enum.count(my_tasks, fn t ->
      t.end_date != nil and Date.compare(t.end_date, Date.utc_today()) == :lt
    end)

    active_projects =
      try do
        Taskboard.Projects.Project
        |> Ash.Query.for_read(:read, %{}, actor: current_user)
        |> Ash.Query.filter(status == :active)
        |> Ash.read!()
        |> length()
      rescue
        _ -> 0
      end

    templates =
      try do
        Taskboard.Templates.Template
        |> Ash.Query.for_read(:read, %{}, actor: current_user)
        |> Ash.Query.filter(status == :active)
        |> Ash.read!()
        |> length()
      rescue
        _ -> 0
      end

    %{
      my_tasks: length(my_tasks),
      overdue: overdue,
      active_projects: active_projects,
      templates: templates
    }
  end
end
