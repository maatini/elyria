defmodule TaskboardWeb.ProjectsLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    projects = load_projects(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Projekte")
     |> assign(:projects, projects)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Page header --%>
    <div class="bg-gradient-to-br from-secondary/8 via-base-100 to-base-100 border-b border-base-300 px-8 py-8">
      <h1 class="text-3xl font-bold tracking-tight">Projekte</h1>
      <p class="text-base-content/60 mt-1 text-sm">
        <span class="font-medium text-base-content/80">{length(@projects)}</span> Projekte gesamt
      </p>
    </div>

    <div class="p-6">
      <%!-- Leer-Zustand --%>
      <div :if={@projects == []} class="flex flex-col items-center justify-center py-24 text-center">
        <div class="size-16 rounded-full bg-base-300 flex items-center justify-center mb-4">
          <.icon name="hero-folder-open" class="size-8 text-base-content/30" />
        </div>
        <h3 class="text-lg font-semibold text-base-content/60">Noch keine Projekte</h3>
        <p class="text-sm text-base-content/40 mt-1">
          Projekte werden aus Vorlagen im Admin-Bereich aktiviert.
        </p>
        <.link navigate={~p"/admin"} class="btn btn-primary btn-sm mt-4">
          Zum Admin-Bereich
        </.link>
      </div>

      <%!-- Projekt-Grid --%>
      <div class="grid sm:grid-cols-2 xl:grid-cols-3 gap-4">
        <div
          :for={project <- @projects}
          class="card bg-base-200 border border-base-300 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-150 overflow-hidden"
        >
          <%!-- Status-Akzentbalken --%>
          <div class={["h-1 w-full", status_accent_class(project.status)]}></div>

          <div class="card-body p-5">
            <div class="flex items-start gap-3 mb-3">
              <div class={[
                "size-10 rounded-lg flex items-center justify-center shrink-0",
                status_icon_bg(project.status)
              ]}>
                <.icon name="hero-folder-open" class={["size-5", status_icon_color(project.status)]} />
              </div>
              <div class="flex-1 min-w-0">
                <h2 class="font-semibold text-base leading-tight truncate">{project.name}</h2>
                <p :if={project.description} class="text-xs text-base-content/50 mt-0.5 truncate">
                  {project.description}
                </p>
              </div>
            </div>

            <div class="flex flex-wrap gap-1.5 mb-4">
              <span class={["badge badge-sm", status_badge_class(project.status)]}>
                {status_label(project.status)}
              </span>
              <span :if={project.reference_date} class="badge badge-ghost badge-sm">
                <.icon name="hero-calendar-mini" class="size-3 mr-1" />
                {Calendar.strftime(project.reference_date, "%d.%m.%Y")}
              </span>
            </div>

            <div class="card-actions mt-auto gap-2">
              <.link
                navigate={~p"/projects/#{project.id}/gantt"}
                class="btn btn-primary btn-sm gap-1.5 flex-1"
              >
                <.icon name="hero-chart-bar" class="size-4" /> Gantt
              </.link>
              <.link
                navigate={~p"/projects/#{project.id}/milestones"}
                class="btn btn-ghost btn-sm gap-1.5"
              >
                <.icon name="hero-flag" class="size-4" /> Meilensteine
              </.link>
              <.link
                navigate={~p"/projects/#{project.id}"}
                class="btn btn-ghost btn-sm gap-1.5"
                title="Kommentare & Anhänge"
              >
                <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" />
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_projects(actor) do
    Taskboard.Projects.Project
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  rescue
    _ -> []
  end

  defp status_label(:draft), do: "Entwurf"
  defp status_label(:active), do: "Aktiv"
  defp status_label(:paused), do: "Pausiert"
  defp status_label(:completed), do: "Abgeschlossen"
  defp status_label(:archived), do: "Archiviert"
  defp status_label(other), do: to_string(other)

  defp status_badge_class(:draft), do: "badge-ghost"
  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:paused), do: "badge-warning"
  defp status_badge_class(:completed), do: "badge-info"
  defp status_badge_class(:archived), do: "badge-neutral"
  defp status_badge_class(_), do: "badge-ghost"

  defp status_accent_class(:active), do: "bg-success"
  defp status_accent_class(:paused), do: "bg-warning"
  defp status_accent_class(:completed), do: "bg-info"
  defp status_accent_class(:archived), do: "bg-neutral"
  defp status_accent_class(_), do: "bg-base-300"

  defp status_icon_bg(:active), do: "bg-success/15"
  defp status_icon_bg(:paused), do: "bg-warning/15"
  defp status_icon_bg(:completed), do: "bg-info/15"
  defp status_icon_bg(_), do: "bg-base-300"

  defp status_icon_color(:active), do: "text-success"
  defp status_icon_color(:paused), do: "text-warning"
  defp status_icon_color(:completed), do: "text-info"
  defp status_icon_color(_), do: "text-base-content/50"
end
