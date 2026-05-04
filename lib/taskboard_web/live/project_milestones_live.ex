defmodule TaskboardWeb.ProjectMilestonesLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @impl true
  def mount(%{"id" => project_id}, _session, socket) do
    case load_project(project_id, socket.assigns.current_user) do
      {:ok, project} ->
        milestones = load_milestones(project_id, socket.assigns.current_user)
        tasks = load_tasks(project_id, socket.assigns.current_user)

        {:ok,
         socket
         |> assign(:page_title, "Meilensteine – #{project.name}")
         |> assign(:project, project)
         |> assign(:milestones, milestones)
         |> assign(:tasks, tasks)
         |> assign(:modal, nil)
         |> assign(:form_data, %{})
         |> assign(:form_errors, [])}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Projekt nicht gefunden.")
         |> push_navigate(to: ~p"/projects")}
    end
  end

  @impl true
  def handle_event("open_create", _params, socket) do
    {:noreply, assign(socket, :modal, :create)}
  end

  @impl true
  def handle_event("open_edit", %{"id" => id}, socket) do
    milestone = Enum.find(socket.assigns.milestones, &(&1.id == id))

    form_data = %{
      "name" => milestone.name,
      "description" => milestone.description || "",
      "due_date" => date_to_string(milestone.due_date),
      "warning_date" => date_to_string(milestone.warning_date)
    }

    {:noreply,
     socket
     |> assign(:modal, {:edit, milestone})
     |> assign(:form_data, form_data)
     |> assign(:form_errors, [])}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal, nil)
     |> assign(:form_data, %{})
     |> assign(:form_errors, [])}
  end

  @impl true
  def handle_event("form_change", %{"milestone" => params}, socket) do
    {:noreply, assign(socket, :form_data, params)}
  end

  @impl true
  def handle_event("save_create", %{"milestone" => params}, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      due_date: parse_date(params["due_date"]),
      warning_date: parse_date(params["warning_date"]),
      project_id: socket.assigns.project.id
    }

    case Ash.create(Taskboard.Projects.Milestone, attrs,
           actor: socket.assigns.current_user,
           authorize?: false
         ) do
      {:ok, _} ->
        milestones = load_milestones(socket.assigns.project.id, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:milestones, milestones)
         |> assign(:modal, nil)
         |> assign(:form_data, %{})
         |> assign(:form_errors, [])
         |> put_flash(:info, "Meilenstein erstellt.")}

      {:error, %Ash.Error.Invalid{} = error} ->
        {:noreply, assign(socket, :form_errors, format_errors(error))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Fehler beim Erstellen.")}
    end
  end

  @impl true
  def handle_event("save_edit", %{"milestone" => params, "_milestone_id" => id}, socket) do
    milestone = Enum.find(socket.assigns.milestones, &(&1.id == id))

    attrs = %{
      name: params["name"],
      description: params["description"],
      due_date: parse_date(params["due_date"]),
      warning_date: parse_date(params["warning_date"])
    }

    case Ash.update(milestone, attrs,
           action: :update,
           actor: socket.assigns.current_user,
           authorize?: false
         ) do
      {:ok, _} ->
        milestones = load_milestones(socket.assigns.project.id, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:milestones, milestones)
         |> assign(:modal, nil)
         |> assign(:form_data, %{})
         |> assign(:form_errors, [])
         |> put_flash(:info, "Meilenstein aktualisiert.")}

      {:error, %Ash.Error.Invalid{} = error} ->
        {:noreply, assign(socket, :form_errors, format_errors(error))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Fehler beim Speichern.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    milestone = Enum.find(socket.assigns.milestones, &(&1.id == id))

    case Ash.destroy(milestone, actor: socket.assigns.current_user, authorize?: false) do
      :ok ->
        milestones = load_milestones(socket.assigns.project.id, socket.assigns.current_user)
        tasks = load_tasks(socket.assigns.project.id, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:milestones, milestones)
         |> assign(:tasks, tasks)
         |> put_flash(:info, "Meilenstein gelöscht.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Fehler beim Löschen.")}
    end
  end

  @impl true
  def handle_event("toggle_task", %{"task-id" => task_id, "milestone-id" => milestone_id}, socket) do
    task = Enum.find(socket.assigns.tasks, &(&1.id == task_id))

    new_milestone_id =
      if task.milestone_id == milestone_id, do: nil, else: milestone_id

    case Ash.update(task, %{milestone_id: new_milestone_id},
           action: :assign_milestone,
           actor: socket.assigns.current_user,
           authorize?: false
         ) do
      {:ok, _} ->
        milestones = load_milestones(socket.assigns.project.id, socket.assigns.current_user)
        tasks = load_tasks(socket.assigns.project.id, socket.assigns.current_user)
        {:noreply, socket |> assign(:milestones, milestones) |> assign(:tasks, tasks)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Fehler beim Zuordnen.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Page header --%>
    <div class="bg-gradient-to-br from-info/8 via-base-100 to-base-100 border-b border-base-300 px-8 py-8">
      <div class="flex items-center gap-2 text-sm text-base-content/50 mb-2">
        <.link navigate={~p"/projects"} class="hover:text-base-content transition-colors">
          Projekte
        </.link>
        <.icon name="hero-chevron-right-mini" class="size-3" />
        <.link
          navigate={~p"/projects/#{@project.id}/gantt"}
          class="hover:text-base-content transition-colors"
        >
          {@project.name}
        </.link>
        <.icon name="hero-chevron-right-mini" class="size-3" />
        <span>Meilensteine</span>
      </div>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold tracking-tight">Meilensteine</h1>
          <p class="text-base-content/60 mt-1 text-sm">
            <span class="font-medium text-base-content/80">{length(@milestones)}</span>
            Meilensteine in diesem Projekt
          </p>
        </div>
        <button class="btn btn-primary gap-2" phx-click="open_create">
          <.icon name="hero-plus" class="size-4" />
          Neuer Meilenstein
        </button>
      </div>
    </div>

    <div class="p-6 max-w-4xl">
      <%!-- Leer-Zustand --%>
      <div :if={@milestones == []} class="flex flex-col items-center justify-center py-24 text-center">
        <div class="size-16 rounded-full bg-base-300 flex items-center justify-center mb-4">
          <.icon name="hero-flag" class="size-8 text-base-content/30" />
        </div>
        <h3 class="text-lg font-semibold text-base-content/60">Noch keine Meilensteine</h3>
        <p class="text-sm text-base-content/40 mt-1">
          Erstelle einen Meilenstein und weise ihm Tasks zu.
        </p>
        <button class="btn btn-primary btn-sm mt-4" phx-click="open_create">
          Ersten Meilenstein erstellen
        </button>
      </div>

      <%!-- Meilenstein-Liste --%>
      <div class="space-y-4">
        <div :for={milestone <- @milestones} class="card bg-base-200 border border-base-300">
          <%!-- Status-Akzentbalken --%>
          <div class={["h-1 w-full rounded-t-box", milestone_accent(milestone)]}></div>

          <div class="card-body p-5">
            <%!-- Header --%>
            <div class="flex items-start justify-between gap-4">
              <div class="flex items-start gap-3 flex-1 min-w-0">
                <div class={["size-10 rounded-lg flex items-center justify-center shrink-0", milestone_icon_bg(milestone)]}>
                  <.icon name="hero-flag" class={["size-5", milestone_icon_color(milestone)]} />
                </div>
                <div class="flex-1 min-w-0">
                  <h3 class="font-semibold text-base">{milestone.name}</h3>
                  <p :if={milestone.description} class="text-sm text-base-content/50 mt-0.5">
                    {milestone.description}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-2 shrink-0">
                <span class={["badge badge-sm", milestone_badge_class(milestone)]}>
                  {milestone_status_label(milestone)}
                </span>
                <button
                  class="btn btn-ghost btn-xs"
                  phx-click="open_edit"
                  phx-value-id={milestone.id}
                >
                  <.icon name="hero-pencil" class="size-3.5" />
                </button>
                <button
                  class="btn btn-ghost btn-xs text-error"
                  phx-click="delete"
                  phx-value-id={milestone.id}
                  data-confirm={"Meilenstein '#{milestone.name}' wirklich löschen?"}
                >
                  <.icon name="hero-trash" class="size-3.5" />
                </button>
              </div>
            </div>

            <%!-- Datums-Info --%>
            <div class="flex gap-4 mt-3 text-xs text-base-content/50">
              <span class="flex items-center gap-1">
                <.icon name="hero-exclamation-triangle-mini" class="size-3 text-warning" />
                Warnung: {format_date(milestone.warning_date)}
              </span>
              <span class="flex items-center gap-1">
                <.icon name="hero-calendar-mini" class="size-3" />
                Fällig: {format_date(milestone.due_date)}
              </span>
            </div>

            <%!-- Fortschrittsbalken --%>
            <% milestone_tasks = Enum.filter(@tasks, &(&1.milestone_id == milestone.id))
            done_count = Enum.count(milestone_tasks, &(&1.status in [:done, :skipped]))
            total_count = length(milestone_tasks) %>

            <div :if={total_count > 0} class="mt-3">
              <div class="flex justify-between text-xs text-base-content/50 mb-1">
                <span>{done_count} / {total_count} Tasks erledigt</span>
                <span>{progress_percent(done_count, total_count)}%</span>
              </div>
              <div class="w-full bg-base-300 rounded-full h-1.5">
                <div
                  class={["h-1.5 rounded-full transition-all", progress_bar_color(milestone)]}
                  style={"width: #{progress_percent(done_count, total_count)}%"}
                >
                </div>
              </div>
            </div>

            <%!-- Task-Zuordnung (expandierbar) --%>
            <details class="mt-4">
              <summary class="text-xs font-medium text-base-content/50 cursor-pointer hover:text-base-content transition-colors select-none">
                Tasks zuordnen ({length(milestone_tasks)} zugeordnet)
              </summary>
              <div class="mt-3 space-y-1 max-h-48 overflow-y-auto pr-1">
                <div :if={@tasks == []} class="text-xs text-base-content/40 py-2">
                  Keine Tasks im Projekt vorhanden.
                </div>
                <label
                  :for={task <- @tasks}
                  class="flex items-center gap-2 px-2 py-1.5 rounded hover:bg-base-300 cursor-pointer"
                >
                  <input
                    type="checkbox"
                    class="checkbox checkbox-xs checkbox-primary"
                    checked={task.milestone_id == milestone.id}
                    phx-click="toggle_task"
                    phx-value-task-id={task.id}
                    phx-value-milestone-id={milestone.id}
                  />
                  <span class="text-sm flex-1 truncate">{task.title}</span>
                  <span class={["badge badge-xs", task_status_badge(task.status)]}>
                    {task_status_label(task.status)}
                  </span>
                </label>
              </div>
            </details>
          </div>
        </div>
      </div>
    </div>

    <%!-- Erstellen-Modal --%>
    <dialog id="create-modal" class={["modal", @modal == :create && "modal-open"]}>
      <div class="modal-box max-w-md">
        <h3 class="text-lg font-bold mb-4">Neuer Meilenstein</h3>
        <form phx-submit="save_create" phx-change="form_change">
          <.milestone_form form_data={@form_data} form_errors={@form_errors} />
          <div class="modal-action">
            <button type="button" class="btn btn-ghost btn-sm" phx-click="close_modal">
              Abbrechen
            </button>
            <button type="submit" class="btn btn-primary btn-sm">Erstellen</button>
          </div>
        </form>
      </div>
      <div class="modal-backdrop" phx-click="close_modal"></div>
    </dialog>

    <%!-- Bearbeiten-Modal --%>
    <dialog
      id="edit-modal"
      class={["modal", match?({:edit, _}, @modal) && "modal-open"]}
    >
      <div class="modal-box max-w-md">
        <h3 class="text-lg font-bold mb-4">Meilenstein bearbeiten</h3>
        <form
          :if={match?({:edit, _}, @modal)}
          phx-submit="save_edit"
          phx-change="form_change"
        >
          <input type="hidden" name="_milestone_id" value={elem(@modal, 1).id} />
          <.milestone_form form_data={@form_data} form_errors={@form_errors} />
          <div class="modal-action">
            <button type="button" class="btn btn-ghost btn-sm" phx-click="close_modal">
              Abbrechen
            </button>
            <button type="submit" class="btn btn-primary btn-sm">Speichern</button>
          </div>
        </form>
      </div>
      <div class="modal-backdrop" phx-click="close_modal"></div>
    </dialog>
    """
  end

  attr :form_data, :map, required: true
  attr :form_errors, :list, required: true

  defp milestone_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div :for={error <- @form_errors} class="alert alert-error py-2 text-sm">
        {error}
      </div>

      <div class="form-control">
        <label class="label"><span class="label-text font-medium">Name *</span></label>
        <input
          type="text"
          name="milestone[name]"
          value={Map.get(@form_data, "name", "")}
          class="input input-bordered"
          placeholder="z.B. Go-Live bereit"
          required
        />
      </div>

      <div class="form-control">
        <label class="label"><span class="label-text font-medium">Beschreibung</span></label>
        <textarea
          name="milestone[description]"
          class="textarea textarea-bordered"
          rows="2"
          placeholder="Optional"
        >{Map.get(@form_data, "description", "")}</textarea>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div class="form-control">
          <label class="label"><span class="label-text font-medium">Warndatum *</span></label>
          <input
            type="date"
            name="milestone[warning_date]"
            value={Map.get(@form_data, "warning_date", "")}
            class="input input-bordered"
            required
          />
        </div>
        <div class="form-control">
          <label class="label"><span class="label-text font-medium">Fälligkeitsdatum *</span></label>
          <input
            type="date"
            name="milestone[due_date]"
            value={Map.get(@form_data, "due_date", "")}
            class="input input-bordered"
            required
          />
        </div>
      </div>
      <p class="text-xs text-base-content/50">
        Das Warndatum muss vor dem Fälligkeitsdatum liegen.
      </p>
    </div>
    """
  end

  # --- Data loading ---

  defp load_project(project_id, actor) do
    Ash.get(Taskboard.Projects.Project, project_id, actor: actor, authorize?: false)
  end

  defp load_milestones(project_id, actor) do
    Taskboard.Projects.Milestone
    |> Ash.Query.for_read(:for_project, %{project_id: project_id}, actor: actor)
    |> Ash.Query.load([:fulfilled?, :overdue?, :warning?])
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  defp load_tasks(project_id, actor) do
    Taskboard.Projects.ProjectTask
    |> Ash.Query.filter(project_id == ^project_id and is_nil(parent_id))
    |> Ash.Query.sort(position: :asc)
    |> Ash.read!(actor: actor, authorize?: false)
  rescue
    _ -> []
  end

  # --- Helpers ---

  defp milestone_accent(%{fulfilled?: true}), do: "bg-success"
  defp milestone_accent(%{overdue?: true}), do: "bg-error"
  defp milestone_accent(%{warning?: true}), do: "bg-warning"
  defp milestone_accent(_), do: "bg-base-300"

  defp milestone_icon_bg(%{fulfilled?: true}), do: "bg-success/15"
  defp milestone_icon_bg(%{overdue?: true}), do: "bg-error/15"
  defp milestone_icon_bg(%{warning?: true}), do: "bg-warning/15"
  defp milestone_icon_bg(_), do: "bg-info/15"

  defp milestone_icon_color(%{fulfilled?: true}), do: "text-success"
  defp milestone_icon_color(%{overdue?: true}), do: "text-error"
  defp milestone_icon_color(%{warning?: true}), do: "text-warning"
  defp milestone_icon_color(_), do: "text-info"

  defp milestone_badge_class(%{fulfilled?: true}), do: "badge-success"
  defp milestone_badge_class(%{overdue?: true}), do: "badge-error"
  defp milestone_badge_class(%{warning?: true}), do: "badge-warning"
  defp milestone_badge_class(_), do: "badge-ghost"

  defp milestone_status_label(%{fulfilled?: true}), do: "Erfüllt"
  defp milestone_status_label(%{overdue?: true}), do: "Überfällig"
  defp milestone_status_label(%{warning?: true}), do: "Warnung"
  defp milestone_status_label(_), do: "Ausstehend"

  defp progress_bar_color(%{fulfilled?: true}), do: "bg-success"
  defp progress_bar_color(%{overdue?: true}), do: "bg-error"
  defp progress_bar_color(%{warning?: true}), do: "bg-warning"
  defp progress_bar_color(_), do: "bg-primary"

  defp progress_percent(_, 0), do: 0
  defp progress_percent(done, total), do: round(done / total * 100)

  defp task_status_badge(:open), do: "badge-ghost"
  defp task_status_badge(:in_progress), do: "badge-info"
  defp task_status_badge(:done), do: "badge-success"
  defp task_status_badge(:skipped), do: "badge-neutral"
  defp task_status_badge(:blocked), do: "badge-error"
  defp task_status_badge(_), do: "badge-ghost"

  defp task_status_label(:open), do: "Offen"
  defp task_status_label(:in_progress), do: "In Arbeit"
  defp task_status_label(:done), do: "Erledigt"
  defp task_status_label(:skipped), do: "Übersprungen"
  defp task_status_label(:blocked), do: "Blockiert"
  defp task_status_label(other), do: to_string(other)

  defp format_date(nil), do: "–"
  defp format_date(date), do: Calendar.strftime(date, "%d.%m.%Y")

  defp date_to_string(nil), do: ""
  defp date_to_string(date), do: Date.to_iso8601(date)

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp format_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.map(errors, fn
      %{message: msg, field: field} when not is_nil(field) -> "#{field}: #{msg}"
      %{message: msg} -> msg
      error -> inspect(error)
    end)
  end
end
