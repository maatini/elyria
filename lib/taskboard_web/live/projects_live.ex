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
    <div class="p-6 max-w-5xl mx-auto">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">Projekte</h1>
        <span class="badge badge-neutral"><%= length(@projects) %></span>
      </div>

      <div :if={@projects == []} class="text-center py-16 text-base-content/40">
        <p>Noch keine Projekte vorhanden.</p>
      </div>

      <div class="grid gap-4">
        <div
          :for={project <- @projects}
          class="card bg-base-200 shadow-sm hover:shadow-md transition-shadow"
        >
          <div class="card-body py-4">
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <h2 class="card-title text-base truncate"><%= project.name %></h2>
                <p :if={project.description} class="text-sm text-base-content/60 mt-1 truncate">
                  <%= project.description %>
                </p>
                <div class="flex flex-wrap gap-2 mt-2">
                  <span class={["badge badge-sm", status_badge_class(project.status)]}>
                    <%= status_label(project.status) %>
                  </span>
                  <span :if={project.reference_date} class="badge badge-ghost badge-sm">
                    Ref: <%= Calendar.strftime(project.reference_date, "%d.%m.%Y") %>
                  </span>
                </div>
              </div>
              <.link navigate={~p"/projects/#{project.id}/gantt"} class="btn btn-primary btn-sm shrink-0">
                Gantt
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
end
