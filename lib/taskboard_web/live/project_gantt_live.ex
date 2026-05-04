defmodule TaskboardWeb.ProjectGanttLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @view_modes ["Day", "Week", "Month"]

  @impl true
  def mount(%{"id" => project_id}, _session, socket) do
    case load_project(project_id, socket.assigns.current_user) do
      {:ok, project} ->
        tasks = load_tasks(project, socket.assigns.current_user)
        gantt_tasks = to_gantt_tasks(tasks)

        {:ok,
         socket
         |> assign(:page_title, project.name)
         |> assign(:project, project)
         |> assign(:tasks, tasks)
         |> assign(:gantt_tasks_json, Jason.encode!(gantt_tasks))
         |> assign(:view_mode, "Week")
         |> assign(:view_modes, @view_modes)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Projekt nicht gefunden.")
         |> redirect(to: ~p"/projects")}
    end
  end

  @impl true
  def handle_event("set-view-mode", %{"mode" => mode}, socket) when mode in @view_modes do
    {:noreply,
     socket
     |> assign(:view_mode, mode)
     |> push_event("set-view-mode", %{mode: mode})}
  end

  @impl true
  def handle_event(
        "gantt-date-change",
        %{"task_id" => task_id, "start" => start, "end" => end_date},
        socket
      ) do
    with task when not is_nil(task) <- Enum.find(socket.assigns.tasks, &(&1.id == task_id)),
         {:ok, start_date} <- Date.from_iso8601(start),
         {:ok, end_d} <- Date.from_iso8601(end_date) do
      case Ash.update(task, %{start_date: start_date, end_date: end_d},
             action: :update,
             actor: socket.assigns.current_user
           ) do
        {:ok, _} ->
          tasks = load_tasks(socket.assigns.project, socket.assigns.current_user)
          gantt_tasks = to_gantt_tasks(tasks)

          {:noreply,
           socket
           |> assign(:tasks, tasks)
           |> assign(:gantt_tasks_json, Jason.encode!(gantt_tasks))
           |> push_event("update-gantt", %{tasks: gantt_tasks})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Datum konnte nicht gespeichert werden.")}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("gantt-task-click", %{"task_id" => _task_id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 max-w-full">
      <div class="flex items-center gap-4 mb-4">
        <.link navigate={~p"/projects"} class="btn btn-ghost btn-sm">
          ← Projekte
        </.link>
        <h1 class="text-xl font-bold flex-1">{@project.name}</h1>

        <div class="join">
          <button
            :for={mode <- @view_modes}
            class={["join-item btn btn-sm", @view_mode == mode && "btn-primary"]}
            phx-click="set-view-mode"
            phx-value-mode={mode}
          >
            {mode}
          </button>
        </div>
      </div>

      <div :if={@tasks == []} class="text-center py-16 text-base-content/40">
        <p>Keine Aufgaben in diesem Projekt.</p>
      </div>

      <div
        :if={@tasks != []}
        id="gantt-wrapper"
        phx-hook="GanttHook"
        data-tasks={@gantt_tasks_json}
        data-view-mode={@view_mode}
        class="overflow-x-auto"
      >
        <div data-gantt-target class="w-full"></div>
      </div>
    </div>
    """
  end

  defp load_project(id, actor) do
    Taskboard.Projects.Project
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.limit(1)
    |> Ash.read_one()
  end

  defp load_tasks(project, actor) do
    Taskboard.Projects.ProjectTask
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(project_id == ^project.id)
    |> Ash.Query.load([
      :parent,
      :assigned_group,
      :chapter_number,
      :incoming_dependencies,
      :overdue?,
      :warning?
    ])
    |> Ash.Query.sort(level: :asc, position: :asc)
    |> Ash.read!()
  rescue
    e ->
      require Logger
      Logger.error("load_tasks failed: #{inspect(e)}")
      []
  end

  defp to_gantt_tasks(tasks) do
    today = Date.utc_today()

    Enum.flat_map(tasks, fn task ->
      start = task.start_date || today
      end_d = task.end_date || Date.add(start, 1)

      if start == end_d do
        []
      else
        deps =
          task.incoming_dependencies
          |> Enum.map(& &1.predecessor_id)
          |> Enum.join(",")

        label =
          if task.chapter_number,
            do: "#{task.chapter_number} #{task.title}",
            else: task.title

        group_name = task.assigned_group && task.assigned_group.name

        subtitle =
          [
            group_name && "Gruppe: #{group_name}",
            "Status: #{status_de(task.status)}",
            task.start_date && "Start: #{Calendar.strftime(task.start_date, "%d.%m.%Y")}",
            task.end_date && "Ende: #{Calendar.strftime(task.end_date, "%d.%m.%Y")}"
          ]
          |> Enum.filter(& &1)
          |> Enum.join(" · ")

        custom_class =
          cond do
            task.overdue? == true -> "gantt-overdue"
            task.warning? == true -> "gantt-warning"
            true -> "gantt-#{task.status}"
          end

        [
          %{
            id: task.id,
            name: label,
            start: Date.to_iso8601(start),
            end: Date.to_iso8601(end_d),
            progress: if(task.status in [:done, :skipped], do: 100, else: 0),
            dependencies: deps,
            custom_class: custom_class,
            custom_popup: subtitle
          }
        ]
      end
    end)
  end

  defp status_de(:open), do: "Offen"
  defp status_de(:blocked), do: "Blockiert"
  defp status_de(:in_progress), do: "In Arbeit"
  defp status_de(:done), do: "Erledigt"
  defp status_de(:skipped), do: "Übersprungen"
  defp status_de(other), do: to_string(other)
end
