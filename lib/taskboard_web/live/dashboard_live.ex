defmodule TaskboardWeb.DashboardLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    stats = load_stats(current_user)
    critical = load_critical_tasks(current_user)
    critical_milestones = load_critical_milestones(current_user)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:stats, stats)
     |> assign(:critical_tasks, critical)
     |> assign(:critical_milestones, critical_milestones)
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
          <span class="badge badge-warning ml-auto">{length(@critical_tasks)}</span>
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
              <tr
                :for={task <- @critical_tasks}
                class={(task.overdue? && "bg-error/10") || "bg-warning/10"}
              >
                <td>
                  <span :if={task.overdue?} class="badge badge-error badge-xs">!</span>
                  <span :if={!task.overdue?} class="badge badge-warning badge-xs">~</span>
                </td>
                <td class="font-medium">{task.title}</td>
                <td class="text-xs text-base-content/60">
                  {(task.project && task.project.name) || "–"}
                </td>
                <td>
                  <span :if={task.assigned_group} class="badge badge-ghost badge-xs">
                    {task.assigned_group.name}
                  </span>
                </td>
                <td class="text-xs">
                  {(task.end_date && Calendar.strftime(task.end_date, "%d.%m.%Y")) || "–"}
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

    <%!-- Hero-Bereich --%>
    <div class="bg-gradient-to-br from-primary/10 via-base-100 to-base-100 border-b border-base-300 px-8 py-8">
      <p class="text-sm text-base-content/50 font-medium mb-1">
        {Calendar.strftime(Date.utc_today(), "%A, %d. %B %Y")}
      </p>
      <h1 class="text-3xl font-bold tracking-tight">Dashboard</h1>
      <p class="text-base-content/60 mt-1 text-sm">
        Willkommen zurück, <span class="font-medium text-base-content/80">{@current_user.email}</span>
      </p>
    </div>

    <div class="p-6 max-w-5xl">
      <%!-- Stat-Karten --%>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div class="card bg-base-200 border border-base-300 hover:shadow-md transition-shadow">
          <div class="card-body p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                Meine Aufgaben
              </span>
              <div class="size-8 rounded-lg bg-primary/15 flex items-center justify-center">
                <.icon name="hero-clipboard-document-check" class="size-4 text-primary" />
              </div>
            </div>
            <div class="text-3xl font-bold text-primary">{@stats.my_tasks}</div>
            <div class="text-xs text-base-content/50 mt-1">offen / in Arbeit</div>
          </div>
        </div>

        <div
          class={[
            "card border hover:shadow-md transition-shadow cursor-pointer",
            if(@stats.overdue > 0, do: "bg-error/10 border-error/30", else: "bg-base-200 border-base-300")
          ]}
          phx-click={@stats.overdue > 0 && JS.dispatch("click", to: "#critical-tasks-dialog")}
        >
          <div class="card-body p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                Überfällig
              </span>
              <div class={[
                "size-8 rounded-lg flex items-center justify-center",
                if(@stats.overdue > 0, do: "bg-error/20", else: "bg-success/15")
              ]}>
                <.icon
                  name={if(@stats.overdue > 0, do: "hero-exclamation-triangle", else: "hero-check-circle")}
                  class={["size-4", if(@stats.overdue > 0, do: "text-error", else: "text-success")]}
                />
              </div>
            </div>
            <div class={["text-3xl font-bold", if(@stats.overdue > 0, do: "text-error", else: "text-success")]}>
              {@stats.overdue}
            </div>
            <div class="text-xs text-base-content/50 mt-1">
              {if(@stats.overdue > 0, do: "Aufgaben überfällig", else: "Alles im Plan")}
            </div>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300 hover:shadow-md transition-shadow">
          <div class="card-body p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                Projekte
              </span>
              <div class="size-8 rounded-lg bg-secondary/15 flex items-center justify-center">
                <.icon name="hero-folder-open" class="size-4 text-secondary" />
              </div>
            </div>
            <div class="text-3xl font-bold">{@stats.active_projects}</div>
            <div class="text-xs text-base-content/50 mt-1">aktive Projekte</div>
          </div>
        </div>

        <div class="card bg-base-200 border border-base-300 hover:shadow-md transition-shadow">
          <div class="card-body p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                Vorlagen
              </span>
              <div class="size-8 rounded-lg bg-info/15 flex items-center justify-center">
                <.icon name="hero-document-duplicate" class="size-4 text-info" />
              </div>
            </div>
            <div class="text-3xl font-bold">{@stats.templates}</div>
            <div class="text-xs text-base-content/50 mt-1">aktive Vorlagen</div>
          </div>
        </div>

        <div
          class={[
            "card border hover:shadow-md transition-shadow",
            if(length(@critical_milestones) > 0,
              do: "bg-warning/10 border-warning/30",
              else: "bg-base-200 border-base-300"
            )
          ]}
        >
          <div class="card-body p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                Meilensteine
              </span>
              <div class={[
                "size-8 rounded-lg flex items-center justify-center",
                if(length(@critical_milestones) > 0, do: "bg-warning/20", else: "bg-base-300")
              ]}>
                <.icon
                  name="hero-flag"
                  class={[
                    "size-4",
                    if(length(@critical_milestones) > 0, do: "text-warning", else: "text-base-content/40")
                  ]}
                />
              </div>
            </div>
            <div class={[
              "text-3xl font-bold",
              if(length(@critical_milestones) > 0, do: "text-warning", else: "")
            ]}>
              {length(@critical_milestones)}
            </div>
            <div class="text-xs text-base-content/50 mt-1">
              {if(length(@critical_milestones) > 0, do: "mit Warnung / überfällig", else: "alles im Plan")}
            </div>
          </div>
        </div>
      </div>

      <%!-- Unterer Bereich --%>
      <div class="grid lg:grid-cols-2 gap-4">
        <%!-- Schnellzugriff --%>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <h2 class="font-semibold text-sm text-base-content/60 uppercase tracking-wider mb-3">
              Schnellzugriff
            </h2>
            <div class="space-y-1">
              <.link
                navigate={~p"/my-tasks"}
                class="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-base-300 transition-colors group"
              >
                <div class="size-8 rounded-lg bg-primary/15 flex items-center justify-center shrink-0">
                  <.icon name="hero-clipboard-document-check" class="size-4 text-primary" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-medium">Meine Aufgaben</div>
                  <div class="text-xs text-base-content/50">{@stats.my_tasks} offen</div>
                </div>
                <.icon
                  name="hero-chevron-right-mini"
                  class="size-4 text-base-content/30 group-hover:text-base-content/60 transition-colors"
                />
              </.link>
              <.link
                navigate={~p"/projects"}
                class="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-base-300 transition-colors group"
              >
                <div class="size-8 rounded-lg bg-secondary/15 flex items-center justify-center shrink-0">
                  <.icon name="hero-folder-open" class="size-4 text-secondary" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-medium">Alle Projekte</div>
                  <div class="text-xs text-base-content/50">{@stats.active_projects} aktiv</div>
                </div>
                <.icon
                  name="hero-chevron-right-mini"
                  class="size-4 text-base-content/30 group-hover:text-base-content/60 transition-colors"
                />
              </.link>
              <.link
                navigate={~p"/templates"}
                class="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-base-300 transition-colors group"
              >
                <div class="size-8 rounded-lg bg-info/15 flex items-center justify-center shrink-0">
                  <.icon name="hero-document-duplicate" class="size-4 text-info" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-medium">Vorlagen</div>
                  <div class="text-xs text-base-content/50">Templates verwalten</div>
                </div>
                <.icon
                  name="hero-chevron-right-mini"
                  class="size-4 text-base-content/30 group-hover:text-base-content/60 transition-colors"
                />
              </.link>
              <.link
                navigate={~p"/admin"}
                class="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-base-300 transition-colors group"
              >
                <div class="size-8 rounded-lg bg-neutral/15 flex items-center justify-center shrink-0">
                  <.icon name="hero-cog-6-tooth" class="size-4 text-neutral-content/60" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-medium">Admin-Bereich</div>
                  <div class="text-xs text-base-content/50">Verwaltung & Einstellungen</div>
                </div>
                <.icon
                  name="hero-chevron-right-mini"
                  class="size-4 text-base-content/30 group-hover:text-base-content/60 transition-colors"
                />
              </.link>
            </div>
          </div>
        </div>

        <%!-- Aktionen --%>
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body p-5">
            <h2 class="font-semibold text-sm text-base-content/60 uppercase tracking-wider mb-3">
              Aktionen
            </h2>

            <div :if={@critical_tasks != []} class="alert bg-warning/15 border border-warning/30 mb-2 p-3">
              <.icon name="hero-exclamation-triangle" class="size-5 text-warning shrink-0" />
              <div class="text-sm">
                <div class="font-medium">{length(@critical_tasks)} kritische Aufgaben</div>
                <div class="text-xs text-base-content/60 mt-0.5">Sofortiger Handlungsbedarf</div>
              </div>
              <button
                class="btn btn-warning btn-xs ml-auto"
                phx-click={
                  JS.set_attribute({"class", "modal modal-open"}, to: "#critical-tasks-dialog")
                }
              >
                Anzeigen
              </button>
            </div>

            <div
              :if={@critical_milestones != []}
              class="alert bg-error/10 border border-error/30 mb-2 p-3"
            >
              <.icon name="hero-flag" class="size-5 text-error shrink-0" />
              <div class="text-sm">
                <div class="font-medium">{length(@critical_milestones)} Meilenstein-Warnungen</div>
                <div class="text-xs text-base-content/60 mt-0.5">
                  {Enum.map_join(Enum.take(@critical_milestones, 2), ", ", & &1.name)}
                  {if length(@critical_milestones) > 2, do: "…", else: ""}
                </div>
              </div>
              <.link
                navigate={~p"/projects"}
                class="btn btn-error btn-xs ml-auto"
              >
                Projekte
              </.link>
            </div>

            <div :if={@critical_tasks == []} class="flex flex-col items-center py-4 text-center">
              <div class="size-12 rounded-full bg-success/15 flex items-center justify-center mb-3">
                <.icon name="hero-check-badge" class="size-6 text-success" />
              </div>
              <div class="text-sm font-medium">Keine kritischen Aufgaben</div>
              <div class="text-xs text-base-content/50 mt-1">Alles läuft planmäßig</div>
            </div>

            <div class="mt-auto pt-3 border-t border-base-300">
              <.link navigate={~p"/admin"} class="btn btn-primary btn-sm w-full">
                <.icon name="hero-cog-6-tooth" class="size-4" /> Admin öffnen
              </.link>
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

  defp load_critical_milestones(current_user) do
    project_ids =
      Taskboard.Projects.Project
      |> Ash.Query.for_read(:read, %{}, actor: current_user)
      |> Ash.Query.filter(status == :active)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    if project_ids == [] do
      []
    else
      Taskboard.Projects.Milestone
      |> Ash.Query.filter(project_id in ^project_ids)
      |> Ash.Query.load([:fulfilled?, :overdue?, :warning?])
      |> Ash.read!(authorize?: false)
      |> Enum.filter(fn m -> m.overdue? == true or m.warning? == true end)
      |> Enum.sort_by(fn m -> {if(m.overdue?, do: 0, else: 1), m.due_date} end)
    end
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

    overdue =
      Enum.count(my_tasks, fn t ->
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
