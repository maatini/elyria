defmodule TaskboardWeb.DashboardLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    stats = load_stats(current_user)
    critical = load_critical_tasks(current_user)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:stats, stats)
     |> assign(:critical_tasks, critical)
     |> assign(:show_alert, critical != [])}
  end

  @impl true
  def handle_event("close_alert", _params, socket) do
    {:noreply, assign(socket, :show_alert, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Kritische Aufgaben Dialog --%>
    <dialog
      id="critical-tasks-dialog"
      class={["modal", @show_alert && "modal-open"]}
      phx-click-away="close_alert"
    >
      <div class="modal-box max-w-2xl">
        <div class="flex items-center gap-3 mb-4">
          <.icon name="hero-exclamation-triangle" class="size-6 text-warning" />
          <h3 class="text-lg font-bold">Kritische Aufgaben</h3>
          <span class="badge badge-warning ml-auto"><%= length(@critical_tasks) %></span>
        </div>

        <p class="text-sm text-base-content/60 mb-4">
          Die folgenden Aufgaben in deinen Gruppen haben das Warn- oder Enddatum erreicht:
        </p>

        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th></th>
                <th>Aufgabe</th>
                <th>Projekt</th>
                <th>Gruppe</th>
                <th>Enddatum</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={task <- @critical_tasks} class={task.overdue? && "bg-error/10" || "bg-warning/10"}>
                <td>
                  <span :if={task.overdue?} class="badge badge-error badge-xs">!</span>
                  <span :if={!task.overdue?} class="badge badge-warning badge-xs">~</span>
                </td>
                <td class="font-medium"><%= task.title %></td>
                <td class="text-xs text-base-content/60">
                  <%= task.project && task.project.name || "–" %>
                </td>
                <td>
                  <span :if={task.assigned_group} class="badge badge-ghost badge-xs">
                    <%= task.assigned_group.name %>
                  </span>
                </td>
                <td class="text-xs">
                  <%= task.end_date && Calendar.strftime(task.end_date, "%d.%m.%Y") || "–" %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="modal-action">
          <.link navigate={~p"/my-tasks"} class="btn btn-sm btn-ghost">
            Alle Aufgaben
          </.link>
          <button class="btn btn-sm btn-primary" phx-click="close_alert">
            Verstanden
          </button>
        </div>
      </div>
    </dialog>

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
        <div
          class={["stat rounded-box cursor-pointer", @stats.overdue > 0 && "bg-error/20" || "bg-base-200"]}
          phx-click={@stats.overdue > 0 && JS.dispatch("click", to: "#critical-tasks-dialog")}
        >
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
              <button
                :if={@critical_tasks != []}
                class="btn btn-warning btn-sm"
                phx-click={JS.set_attribute({"class", "modal modal-open"}, to: "#critical-tasks-dialog")}
              >
                <.icon name="hero-exclamation-triangle" class="size-4" />
                <%= length(@critical_tasks) %> kritische Aufgaben
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_critical_tasks(current_user) do
    Taskboard.Projects.ProjectTask
    |> Ash.Query.for_read(:my_tasks, %{}, actor: current_user)
    |> Ash.Query.load([:project, :assigned_group, :overdue?, :warning?])
    |> Ash.read!()
    |> Enum.filter(fn t -> t.overdue? == true or t.warning? == true end)
    |> Enum.sort_by(fn t -> {if(t.overdue?, do: 0, else: 1), t.end_date} end)
  rescue
    _ -> []
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
