defmodule TaskboardWeb.MyTasksLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    tasks = load_tasks(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Meine Aufgaben")
     |> assign(:tasks, tasks)
     |> assign(:search, "")
     |> assign(:status_filter, :all)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom = String.to_existing_atom(status)
    {:noreply, assign(socket, :status_filter, status_atom)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :filtered_tasks, filtered_tasks(assigns))

    ~H"""
    <%!-- Page header --%>
    <div class="bg-gradient-to-br from-primary/8 via-base-100 to-base-100 border-b border-base-300 px-8 py-8">
      <h1 class="text-3xl font-bold tracking-tight">Meine Aufgaben</h1>
      <p class="text-base-content/60 mt-1 text-sm">
        <span class="font-medium text-base-content/80">{length(@tasks)}</span>
        Aufgaben in deinen Gruppen
      </p>
    </div>

    <div class="p-6 max-w-7xl">
      <%!-- Filter-Leiste --%>
      <div class="flex flex-col sm:flex-row gap-3 mb-6">
        <div class="relative w-full sm:w-80">
          <.icon
            name="hero-magnifying-glass"
            class="size-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40"
          />
          <input
            type="text"
            placeholder="Aufgaben durchsuchen..."
            class="input input-bordered w-full pl-9"
            value={@search}
            phx-change="search"
            name="search"
          />
        </div>

        <div class="tabs tabs-boxed">
          <button
            class={["tab", @status_filter == :all && "tab-active"]}
            phx-click="filter_status"
            phx-value-status="all"
          >
            Alle
          </button>
          <button
            class={["tab", @status_filter == :open && "tab-active"]}
            phx-click="filter_status"
            phx-value-status="open"
          >
            Offen
          </button>
          <button
            class={["tab", @status_filter == :in_progress && "tab-active"]}
            phx-click="filter_status"
            phx-value-status="in_progress"
          >
            In Arbeit
          </button>
        </div>

        <div class="ml-auto badge badge-neutral self-center hidden sm:flex">
          {length(@filtered_tasks)} Ergebnisse
        </div>
      </div>

      <div :if={@filtered_tasks == []} class="flex flex-col items-center justify-center py-20 text-center">
        <div class="size-16 rounded-full bg-base-300 flex items-center justify-center mb-4">
          <.icon name="hero-clipboard-document-check" class="size-8 text-base-content/30" />
        </div>
        <h3 class="text-lg font-semibold text-base-content/60">Keine Aufgaben gefunden</h3>
        <p class="text-sm text-base-content/40 mt-1">
          {if(@search != "", do: "Versuche einen anderen Suchbegriff.", else: "Du hast aktuell keine offenen Aufgaben.")}
        </p>
      </div>

      <div :if={@filtered_tasks != []} class="overflow-x-auto rounded-box border border-base-300">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th class="w-8"></th>
              <th>Aufgabe</th>
              <th>Projekt</th>
              <th>Gruppe</th>
              <th>Status</th>
              <th>Enddatum</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={task <- @filtered_tasks}
              class={[
                "hover",
                task.overdue? && "bg-error/10",
                !task.overdue? && task.warning? && "bg-warning/10"
              ]}
            >
              <td>
                <span :if={task.overdue?} class="badge badge-error badge-sm" title="Überfällig">
                  !
                </span>
                <span
                  :if={!task.overdue? && task.warning?}
                  class="badge badge-warning badge-sm"
                  title="Warnung"
                >
                  ~
                </span>
              </td>
              <td>
                <div class="font-medium">{task.title}</div>
                <div :if={task.chapter_number} class="text-xs text-base-content/50">
                  {task.chapter_number}
                </div>
              </td>
              <td class="text-sm text-base-content/70">
                {(task.project && task.project.name) || "–"}
              </td>
              <td>
                <span :if={task.assigned_group} class="badge badge-ghost badge-sm">
                  {task.assigned_group.name}
                </span>
              </td>
              <td>
                <span class={["badge badge-sm", status_badge_class(task.status)]}>
                  {status_label(task.status)}
                </span>
              </td>
              <td class="text-sm">
                {format_date(task.end_date)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp load_tasks(current_user) do
    Taskboard.Projects.ProjectTask
    |> Ash.Query.for_read(:my_tasks, %{}, actor: current_user)
    |> Ash.Query.load([:project, :assigned_group, :parent, :chapter_number, :overdue?, :warning?])
    |> Ash.read!()
  rescue
    _ -> []
  end

  defp filtered_tasks(assigns) do
    assigns.tasks
    |> filter_by_status(assigns.status_filter)
    |> filter_by_search(assigns.search)
  end

  defp filter_by_status(tasks, :all), do: tasks
  defp filter_by_status(tasks, status), do: Enum.filter(tasks, &(&1.status == status))

  defp filter_by_search(tasks, ""), do: tasks

  defp filter_by_search(tasks, search) do
    search_lower = String.downcase(search)

    Enum.filter(tasks, fn task ->
      String.contains?(String.downcase(task.title), search_lower) or
        (task.project && String.contains?(String.downcase(task.project.name), search_lower))
    end)
  end

  defp status_label(:open), do: "Offen"
  defp status_label(:in_progress), do: "In Arbeit"
  defp status_label(other), do: to_string(other)

  defp status_badge_class(:open), do: "badge-ghost"
  defp status_badge_class(:in_progress), do: "badge-info"
  defp status_badge_class(_), do: "badge-ghost"

  defp format_date(nil), do: "–"
  defp format_date(date), do: Calendar.strftime(date, "%d.%m.%Y")
end
