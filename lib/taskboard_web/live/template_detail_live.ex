defmodule TaskboardWeb.TemplateDetailLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  alias Taskboard.Accounts.Group
  alias Taskboard.Templates.{Template, TemplateTask}

  @task_types [regular: "Standard", main: "Haupt-Task", detail: "Detail-Task"]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case load_template(id, socket.assigns.current_user) do
      {:ok, template} ->
        tasks = load_tasks(template.id, socket.assigns.current_user)
        groups = load_groups(socket.assigns.current_user)

        {:ok,
         socket
         |> assign(:page_title, template.name)
         |> assign(:template, template)
         |> assign(:tasks, tasks)
         |> assign(:groups, groups)
         |> assign(:task_types, @task_types)
         |> assign(:collapsed, MapSet.new())
         |> assign(:add_chapter_form, false)
         |> assign(:new_chapter_title, "")
         |> assign(:add_task_chapter_id, nil)
         |> assign(:new_task_title, "")
         |> assign(:drawer, nil)
         |> assign(:drawer_form, %{})
         |> assign(:drawer_errors, [])}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Vorlage nicht gefunden.")
         |> redirect(to: ~p"/templates")}
    end
  end

  # --- Drawer ---

  @impl true
  def handle_event("open_drawer", %{"id" => id}, socket) do
    case find_task(socket.assigns.tasks, id) do
      nil ->
        {:noreply, socket}

      task ->
        form = task_to_form(task)
        {:noreply, assign(socket, drawer: task, drawer_form: form, drawer_errors: [])}
    end
  end

  @impl true
  def handle_event("close_drawer", _params, socket) do
    {:noreply, assign(socket, drawer: nil, drawer_form: %{}, drawer_errors: [])}
  end

  @impl true
  def handle_event("update_drawer_field", params, socket) do
    field = params["field"]
    value = params["value"]
    form = Map.put(socket.assigns.drawer_form, field, value)
    {:noreply, assign(socket, :drawer_form, form)}
  end

  @impl true
  def handle_event("save_edit", _params, socket) do
    task = socket.assigns.drawer
    attrs = parse_drawer_form(socket.assigns.drawer_form, task.level)

    case Ash.update(task, attrs, action: :update, actor: socket.assigns.current_user) do
      {:ok, _} ->
        tasks = load_tasks(socket.assigns.template.id, socket.assigns.current_user)
        {:noreply, assign(socket, tasks: tasks, drawer: nil, drawer_form: %{}, drawer_errors: [])}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        {:noreply, assign(socket, :drawer_errors, format_errors(errors))}

      {:error, _} ->
        {:noreply, assign(socket, :drawer_errors, ["Unbekannter Fehler"])}
    end
  end

  # --- Chapter add ---

  @impl true
  def handle_event("show_add_chapter", _params, socket) do
    {:noreply, assign(socket, add_chapter_form: true, new_chapter_title: "")}
  end

  @impl true
  def handle_event("cancel_add_chapter", _params, socket) do
    {:noreply, assign(socket, add_chapter_form: false, new_chapter_title: "")}
  end

  @impl true
  def handle_event("update_chapter_title", %{"title" => title}, socket) do
    {:noreply, assign(socket, :new_chapter_title, title)}
  end

  @impl true
  def handle_event("save_chapter", _params, socket) do
    title = String.trim(socket.assigns.new_chapter_title)

    if title == "" do
      {:noreply, socket}
    else
      next_pos = length(chapters_of(socket.assigns.tasks)) + 1

      attrs = %{
        title: title,
        level: 0,
        position: next_pos,
        template_id: socket.assigns.template.id
      }

      case Ash.create(TemplateTask, attrs, actor: socket.assigns.current_user) do
        {:ok, _} ->
          tasks = load_tasks(socket.assigns.template.id, socket.assigns.current_user)
          {:noreply, assign(socket, tasks: tasks, add_chapter_form: false, new_chapter_title: "")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Kapitel konnte nicht erstellt werden.")}
      end
    end
  end

  # --- Task add ---

  @impl true
  def handle_event("show_add_task", %{"chapter_id" => chapter_id}, socket) do
    {:noreply, assign(socket, add_task_chapter_id: chapter_id, new_task_title: "")}
  end

  @impl true
  def handle_event("cancel_add_task", _params, socket) do
    {:noreply, assign(socket, add_task_chapter_id: nil, new_task_title: "")}
  end

  @impl true
  def handle_event("update_task_title", %{"title" => title}, socket) do
    {:noreply, assign(socket, :new_task_title, title)}
  end

  @impl true
  def handle_event("save_task", %{"chapter_id" => chapter_id}, socket) do
    title = String.trim(socket.assigns.new_task_title)

    if title == "" do
      {:noreply, socket}
    else
      next_pos = length(tasks_of_chapter(socket.assigns.tasks, chapter_id)) + 1

      attrs = %{
        title: title,
        level: 1,
        position: next_pos,
        template_id: socket.assigns.template.id,
        parent_id: chapter_id
      }

      case Ash.create(TemplateTask, attrs, actor: socket.assigns.current_user) do
        {:ok, _} ->
          tasks = load_tasks(socket.assigns.template.id, socket.assigns.current_user)
          {:noreply, assign(socket, tasks: tasks, add_task_chapter_id: nil, new_task_title: "")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Aufgabe konnte nicht erstellt werden.")}
      end
    end
  end

  # --- Delete ---

  @impl true
  def handle_event("delete_task", %{"id" => id}, socket) do
    case find_task(socket.assigns.tasks, id) do
      nil ->
        {:noreply, socket}

      task ->
        children = tasks_of_chapter(socket.assigns.tasks, id)
        Enum.each(children, &Ash.destroy!(&1, actor: socket.assigns.current_user))

        case Ash.destroy(task, actor: socket.assigns.current_user) do
          :ok ->
            tasks = load_tasks(socket.assigns.template.id, socket.assigns.current_user)
            {:noreply, assign(socket, tasks: tasks)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Konnte nicht gelöscht werden.")}
        end
    end
  end

  # --- Collapse ---

  @impl true
  def handle_event("toggle_collapse", %{"id" => id}, socket) do
    collapsed =
      if MapSet.member?(socket.assigns.collapsed, id),
        do: MapSet.delete(socket.assigns.collapsed, id),
        else: MapSet.put(socket.assigns.collapsed, id)

    {:noreply, assign(socket, :collapsed, collapsed)}
  end

  # --- Reorder ---

  @impl true
  def handle_event("move_up", %{"id" => id}, socket) do
    case find_task(socket.assigns.tasks, id) do
      nil -> {:noreply, socket}
      task -> {:noreply, do_move(socket, task, sibling_list(socket.assigns.tasks, task), :up)}
    end
  end

  @impl true
  def handle_event("move_down", %{"id" => id}, socket) do
    case find_task(socket.assigns.tasks, id) do
      nil -> {:noreply, socket}
      task -> {:noreply, do_move(socket, task, sibling_list(socket.assigns.tasks, task), :down)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 flex flex-col gap-6">
      <%!-- Breadcrumb + Header --%>
      <div>
        <.link
          navigate={~p"/templates"}
          class="text-sm text-base-content/50 hover:text-base-content flex items-center gap-1 mb-4"
        >
          <.icon name="hero-chevron-left" class="size-4" /> Vorlagen
        </.link>

        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold flex-1">{@template.name}</h1>
          <span class={["badge", status_badge_class(@template.status)]}>
            {status_label(@template.status)}
          </span>
          <span class="text-sm text-base-content/40">{length(@tasks)} Einträge</span>
        </div>
        <p :if={@template.description} class="text-base-content/60 text-sm mt-1">
          {@template.description}
        </p>
      </div>

      <%!-- Aufgaben-Baum --%>
      <div class="flex flex-col gap-1">
        <div :if={chapters_of(@tasks) == []} class="text-center py-12 text-base-content/40">
          <.icon name="hero-document-text" class="size-8 mx-auto mb-2 opacity-30" />
          <p class="text-sm">Noch keine Kapitel vorhanden.</p>
        </div>

        <div
          :for={chapter <- chapters_of(@tasks)}
          class="rounded-box border border-base-300 overflow-hidden"
        >
          <%!-- Kapitel-Header --%>
          <div class="flex items-center gap-2 bg-base-200 px-4 py-2.5 group">
            <button
              class="text-base-content/40 hover:text-base-content"
              phx-click="toggle_collapse"
              phx-value-id={chapter.id}
            >
              <.icon
                name={
                  if MapSet.member?(@collapsed, chapter.id),
                    do: "hero-chevron-right",
                    else: "hero-chevron-down"
                }
                class="size-4"
              />
            </button>
            <span class="text-xs font-mono text-base-content/40 w-6 shrink-0">
              {chapter.position}.
            </span>
            <span class="font-semibold flex-1">{chapter.title}</span>
            <span class="text-xs text-base-content/40">
              {length(tasks_of_chapter(@tasks, chapter.id))} Aufgaben
            </span>

            <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              <button
                class="btn btn-ghost btn-xs"
                title="Bearbeiten"
                phx-click="open_drawer"
                phx-value-id={chapter.id}
              >
                <.icon name="hero-pencil" class="size-3.5" />
              </button>
              <button
                class="btn btn-ghost btn-xs"
                title="Aufgabe hinzufügen"
                phx-click="show_add_task"
                phx-value-chapter_id={chapter.id}
              >
                <.icon name="hero-plus" class="size-3.5" />
              </button>
              <button
                class="btn btn-ghost btn-xs"
                phx-click="move_up"
                phx-value-id={chapter.id}
                disabled={chapter.position == 1}
              >
                <.icon name="hero-chevron-up" class="size-3.5" />
              </button>
              <button
                class="btn btn-ghost btn-xs"
                phx-click="move_down"
                phx-value-id={chapter.id}
                disabled={chapter.position == length(chapters_of(@tasks))}
              >
                <.icon name="hero-chevron-down" class="size-3.5" />
              </button>
              <button
                class="btn btn-ghost btn-xs text-error"
                phx-click="delete_task"
                phx-value-id={chapter.id}
                data-confirm={"Kapitel \"#{chapter.title}\" und alle Aufgaben darin löschen?"}
              >
                <.icon name="hero-trash" class="size-3.5" />
              </button>
            </div>
          </div>

          <%!-- Aufgaben im Kapitel --%>
          <div :if={not MapSet.member?(@collapsed, chapter.id)} class="divide-y divide-base-200">
            <div
              :for={task <- tasks_of_chapter(@tasks, chapter.id)}
              class="flex items-center gap-2 px-4 py-2 hover:bg-base-50 group"
            >
              <span class="text-xs font-mono text-base-content/30 w-8 shrink-0 text-right">
                {chapter.position}.{task.position}
              </span>
              <span class="flex-1 text-sm">{task.title}</span>
              <span
                :if={task.task_type != :regular}
                class="badge badge-outline badge-xs hidden sm:block"
              >
                {task_type_label(task.task_type, @task_types)}
              </span>
              <span
                :if={task.end_offset_days}
                class="text-xs text-base-content/40 hidden sm:block tabular-nums"
              >
                {offset_label(task.start_offset_days, task.end_offset_days)}
              </span>
              <span :if={task.assigned_group} class="badge badge-ghost badge-xs hidden sm:block">
                {task.assigned_group.name}
              </span>

              <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                  class="btn btn-ghost btn-xs"
                  title="Bearbeiten"
                  phx-click="open_drawer"
                  phx-value-id={task.id}
                >
                  <.icon name="hero-pencil" class="size-3.5" />
                </button>
                <button
                  class="btn btn-ghost btn-xs"
                  phx-click="move_up"
                  phx-value-id={task.id}
                  disabled={task.position == 1}
                >
                  <.icon name="hero-chevron-up" class="size-3.5" />
                </button>
                <button
                  class="btn btn-ghost btn-xs"
                  phx-click="move_down"
                  phx-value-id={task.id}
                  disabled={task.position == length(tasks_of_chapter(@tasks, chapter.id))}
                >
                  <.icon name="hero-chevron-down" class="size-3.5" />
                </button>
                <button
                  class="btn btn-ghost btn-xs text-error"
                  phx-click="delete_task"
                  phx-value-id={task.id}
                  data-confirm={"Aufgabe \"#{task.title}\" löschen?"}
                >
                  <.icon name="hero-trash" class="size-3.5" />
                </button>
              </div>
            </div>

            <%!-- Inline: Aufgabe hinzufügen --%>
            <div
              :if={@add_task_chapter_id == chapter.id}
              class="flex items-center gap-2 px-4 py-2 bg-base-100"
            >
              <span class="text-xs font-mono text-base-content/20 w-8 shrink-0 text-right">
                {chapter.position}.{length(tasks_of_chapter(@tasks, chapter.id)) + 1}
              </span>
              <input
                type="text"
                placeholder="Titel der neuen Aufgabe…"
                class="input input-bordered input-sm flex-1"
                value={@new_task_title}
                phx-change="update_task_title"
                phx-keydown="save_task"
                phx-key="Enter"
                phx-value-chapter_id={chapter.id}
                name="title"
                autofocus
              />
              <button
                class="btn btn-primary btn-sm"
                phx-click="save_task"
                phx-value-chapter_id={chapter.id}
                disabled={String.trim(@new_task_title) == ""}
              >
                Hinzufügen
              </button>
              <button class="btn btn-ghost btn-sm" phx-click="cancel_add_task">Abbrechen</button>
            </div>

            <button
              :if={@add_task_chapter_id != chapter.id}
              class="flex items-center gap-2 px-4 py-2 w-full text-left text-sm text-base-content/40 hover:text-base-content hover:bg-base-100 transition-colors"
              phx-click="show_add_task"
              phx-value-chapter_id={chapter.id}
            >
              <.icon name="hero-plus" class="size-3.5" /> Aufgabe hinzufügen
            </button>
          </div>
        </div>

        <%!-- Kapitel hinzufügen --%>
        <div
          :if={@add_chapter_form}
          class="flex items-center gap-2 p-3 border border-dashed border-base-300 rounded-box"
        >
          <.icon name="hero-folder-plus" class="size-4 text-base-content/40 shrink-0" />
          <input
            type="text"
            placeholder="Titel des neuen Kapitels…"
            class="input input-bordered input-sm flex-1"
            value={@new_chapter_title}
            phx-change="update_chapter_title"
            phx-keydown="save_chapter"
            phx-key="Enter"
            name="title"
            autofocus
          />
          <button
            class="btn btn-primary btn-sm"
            phx-click="save_chapter"
            disabled={String.trim(@new_chapter_title) == ""}
          >
            Hinzufügen
          </button>
          <button class="btn btn-ghost btn-sm" phx-click="cancel_add_chapter">Abbrechen</button>
        </div>

        <button
          :if={not @add_chapter_form}
          class="flex items-center gap-2 p-3 w-full text-left text-sm text-base-content/40 hover:text-base-content border border-dashed border-base-300 rounded-box hover:border-base-content/30 transition-colors"
          phx-click="show_add_chapter"
        >
          <.icon name="hero-folder-plus" class="size-4" /> Kapitel hinzufügen
        </button>
      </div>
    </div>

    <%!-- Edit-Drawer --%>
    <div :if={@drawer} class="fixed inset-0 z-40 flex justify-end" phx-click="close_drawer">
      <div class="fixed inset-0 bg-black/30" aria-hidden="true"></div>
      <div
        class="relative z-50 w-full max-w-md bg-base-100 shadow-2xl flex flex-col h-full overflow-y-auto"
        phx-click-away="close_drawer"
      >
        <%!-- Drawer-Header --%>
        <div class="flex items-center gap-3 p-5 border-b border-base-300 sticky top-0 bg-base-100">
          <div class="flex-1">
            <p class="text-xs text-base-content/40">
              {if @drawer.level == 0, do: "Kapitel bearbeiten", else: "Aufgabe bearbeiten"}
            </p>
            <h2 class="font-semibold">{@drawer.title}</h2>
          </div>
          <button class="btn btn-ghost btn-sm btn-circle" phx-click="close_drawer">
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <%!-- Drawer-Body --%>
        <div class="flex-1 p-5 flex flex-col gap-4">
          <div :if={@drawer_errors != []} class="alert alert-error py-2">
            <.icon name="hero-exclamation-circle" class="size-4" />
            <ul class="text-sm list-disc list-inside">
              <li :for={err <- @drawer_errors}>{err}</li>
            </ul>
          </div>

          <%!-- Titel --%>
          <fieldset class="fieldset">
            <legend class="fieldset-legend">Titel *</legend>
            <input
              type="text"
              class="input input-bordered w-full"
              value={Map.get(@drawer_form, "title", "")}
              phx-change="update_drawer_field"
              phx-value-field="title"
              name="title"
            />
          </fieldset>

          <%!-- Beschreibung --%>
          <fieldset class="fieldset">
            <legend class="fieldset-legend">Beschreibung</legend>
            <textarea
              class="textarea textarea-bordered w-full"
              rows="3"
              phx-change="update_drawer_field"
              phx-value-field="description"
              name="description"
            >{Map.get(@drawer_form, "description", "")}</textarea>
          </fieldset>

          <%!-- Nur für Tasks (level 1) --%>
          <div :if={@drawer.level == 1} class="flex flex-col gap-4">
            <%!-- Zeitversatz --%>
            <div class="grid grid-cols-3 gap-3">
              <fieldset class="fieldset">
                <legend class="fieldset-legend">Start (Tage)</legend>
                <input
                  type="number"
                  class="input input-bordered w-full"
                  value={Map.get(@drawer_form, "start_offset_days", "0")}
                  phx-change="update_drawer_field"
                  phx-value-field="start_offset_days"
                  name="start_offset_days"
                />
                <p class="fieldset-label">negativ = vor Referenz</p>
              </fieldset>

              <fieldset class="fieldset">
                <legend class="fieldset-legend">Ende (Tage)</legend>
                <input
                  type="number"
                  class="input input-bordered w-full"
                  value={Map.get(@drawer_form, "end_offset_days", "7")}
                  phx-change="update_drawer_field"
                  phx-value-field="end_offset_days"
                  name="end_offset_days"
                />
              </fieldset>

              <fieldset class="fieldset">
                <legend class="fieldset-legend">Warnung (Tage)</legend>
                <input
                  type="number"
                  class="input input-bordered w-full"
                  placeholder="–"
                  value={Map.get(@drawer_form, "warning_offset_days", "")}
                  phx-change="update_drawer_field"
                  phx-value-field="warning_offset_days"
                  name="warning_offset_days"
                />
                <p class="fieldset-label">vor Ende, optional</p>
              </fieldset>
            </div>

            <%!-- Aufgabentyp --%>
            <fieldset class="fieldset">
              <legend class="fieldset-legend">Aufgabentyp</legend>
              <select
                class="select select-bordered w-full"
                phx-change="update_drawer_field"
                phx-value-field="task_type"
                name="task_type"
              >
                <option
                  :for={{type, label} <- @task_types}
                  value={type}
                  selected={Map.get(@drawer_form, "task_type") == to_string(type)}
                >
                  {label}
                </option>
              </select>
            </fieldset>

            <%!-- Gruppe --%>
            <fieldset class="fieldset">
              <legend class="fieldset-legend">Gruppe</legend>
              <select
                class="select select-bordered w-full"
                phx-change="update_drawer_field"
                phx-value-field="assigned_group_id"
                name="assigned_group_id"
              >
                <option value="" selected={is_nil(Map.get(@drawer_form, "assigned_group_id"))}>
                  – keine –
                </option>
                <option
                  :for={group <- @groups}
                  value={group.id}
                  selected={Map.get(@drawer_form, "assigned_group_id") == group.id}
                >
                  {group.name}
                </option>
              </select>
            </fieldset>
          </div>
        </div>

        <%!-- Drawer-Footer --%>
        <div class="p-5 border-t border-base-300 flex gap-2 justify-end sticky bottom-0 bg-base-100">
          <button class="btn btn-ghost" phx-click="close_drawer">Abbrechen</button>
          <button class="btn btn-primary" phx-click="save_edit">Speichern</button>
        </div>
      </div>
    </div>
    """
  end

  # --- Private helpers ---

  defp do_move(socket, task, siblings, direction) do
    idx = Enum.find_index(siblings, &(&1.id == task.id))

    swap_idx = if direction == :up, do: idx - 1, else: idx + 1

    if swap_idx < 0 or swap_idx >= length(siblings) do
      socket
    else
      partner = Enum.at(siblings, swap_idx)
      actor = socket.assigns.current_user

      with {:ok, temp} <- Ash.update(task, %{position: 99_999}, action: :reorder, actor: actor),
           {:ok, _} <-
             Ash.update(partner, %{position: task.position}, action: :reorder, actor: actor),
           {:ok, _} <-
             Ash.update(temp, %{position: partner.position}, action: :reorder, actor: actor) do
        tasks = load_tasks(socket.assigns.template.id, actor)
        assign(socket, :tasks, tasks)
      else
        _ -> put_flash(socket, :error, "Reihenfolge konnte nicht geändert werden.")
      end
    end
  end

  defp task_to_form(task) do
    %{
      "title" => task.title || "",
      "description" => task.description || "",
      "start_offset_days" => to_string(task.start_offset_days || 0),
      "end_offset_days" => to_string(task.end_offset_days || 7),
      "warning_offset_days" =>
        if(task.warning_offset_days, do: to_string(task.warning_offset_days), else: ""),
      "task_type" => to_string(task.task_type || :regular),
      "assigned_group_id" => task.assigned_group_id
    }
  end

  defp parse_drawer_form(form, level) do
    base = %{
      title: form["title"],
      description: nil_if_blank(form["description"])
    }

    if level == 1 do
      Map.merge(base, %{
        start_offset_days: parse_int(form["start_offset_days"], 0),
        end_offset_days: parse_int(form["end_offset_days"], 7),
        warning_offset_days: parse_optional_int(form["warning_offset_days"]),
        task_type: String.to_existing_atom(form["task_type"] || "regular"),
        assigned_group_id: nil_if_blank(form["assigned_group_id"])
      })
    else
      base
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default

  defp parse_int(s, default) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(""), do: nil

  defp parse_optional_int(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp nil_if_blank(nil), do: nil
  defp nil_if_blank(""), do: nil
  defp nil_if_blank(s), do: s

  defp sibling_list(tasks, %{level: 0}), do: chapters_of(tasks)
  defp sibling_list(tasks, %{level: 1, parent_id: pid}), do: tasks_of_chapter(tasks, pid)

  defp chapters_of(tasks),
    do: tasks |> Enum.filter(&(&1.level == 0)) |> Enum.sort_by(& &1.position)

  defp tasks_of_chapter(tasks, chapter_id) do
    tasks
    |> Enum.filter(&(&1.level == 1 and &1.parent_id == chapter_id))
    |> Enum.sort_by(& &1.position)
  end

  defp find_task(tasks, id), do: Enum.find(tasks, &(&1.id == id))

  defp load_template(id, actor) do
    Template |> Ash.Query.filter(id == ^id) |> Ash.Query.limit(1) |> Ash.read_one(actor: actor)
  end

  defp load_tasks(template_id, actor) do
    TemplateTask
    |> Ash.Query.filter(template_id == ^template_id)
    |> Ash.Query.load([:assigned_group])
    |> Ash.Query.sort(level: :asc, position: :asc)
    |> Ash.read!(actor: actor)
  rescue
    _ -> []
  end

  defp load_groups(actor) do
    Group |> Ash.Query.sort(name: :asc) |> Ash.read!(actor: actor)
  rescue
    _ -> []
  end

  defp format_errors(errors) do
    Enum.map(errors, fn
      %{field: field, message: msg} -> "#{field}: #{msg}"
      %{message: msg} -> msg
      err -> inspect(err)
    end)
  end

  defp offset_label(start_d, end_d) do
    start_str = if start_d && start_d != 0, do: "#{start_d}d", else: "0"
    "#{start_str} → #{end_d}d"
  end

  defp task_type_label(:regular, _), do: nil
  defp task_type_label(type, types), do: Keyword.get(types, type, to_string(type))

  defp status_label(:draft), do: "Entwurf"
  defp status_label(:active), do: "Aktiv"
  defp status_label(:archived), do: "Archiviert"
  defp status_label(other), do: to_string(other)

  defp status_badge_class(:draft), do: "badge-ghost"
  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:archived), do: "badge-neutral"
  defp status_badge_class(_), do: "badge-ghost"
end
