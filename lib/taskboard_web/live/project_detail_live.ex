defmodule TaskboardWeb.ProjectDetailLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @impl true
  def mount(%{"id" => project_id}, _session, socket) do
    case load_project(project_id, socket.assigns.current_user) do
      {:ok, project} ->
        {:ok,
         socket
         |> assign(:page_title, project.name)
         |> assign(:project, project)
         |> assign(:active_tab, :comments)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Projekt nicht gefunden.")
         |> redirect(to: ~p"/projects")}
    end
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 flex flex-col gap-6">
      <%!-- Breadcrumb + Header --%>
      <div>
        <.link
          navigate={~p"/projects"}
          class="text-sm text-base-content/50 hover:text-base-content flex items-center gap-1 mb-4"
        >
          <.icon name="hero-chevron-left" class="size-4" /> Projekte
        </.link>

        <div class="flex items-start gap-4">
          <div class={[
            "size-12 rounded-xl flex items-center justify-center shrink-0",
            status_icon_bg(@project.status)
          ]}>
            <.icon name="hero-folder-open" class={["size-6", status_icon_color(@project.status)]} />
          </div>
          <div class="flex-1 min-w-0">
            <h1 class="text-2xl font-bold">{@project.name}</h1>
            <p :if={@project.description} class="text-base-content/60 text-sm mt-1">
              {@project.description}
            </p>
            <div class="flex flex-wrap gap-2 mt-2">
              <span class={["badge badge-sm", status_badge_class(@project.status)]}>
                {status_label(@project.status)}
              </span>
              <span :if={@project.reference_date} class="badge badge-ghost badge-sm">
                <.icon name="hero-calendar-mini" class="size-3 mr-1" />
                {Calendar.strftime(@project.reference_date, "%d.%m.%Y")}
              </span>
            </div>
          </div>
          <div class="flex gap-2 shrink-0">
            <.link navigate={~p"/projects/#{@project.id}/gantt"} class="btn btn-ghost btn-sm gap-1">
              <.icon name="hero-chart-bar" class="size-4" /> Gantt
            </.link>
            <.link
              navigate={~p"/projects/#{@project.id}/milestones"}
              class="btn btn-ghost btn-sm gap-1"
            >
              <.icon name="hero-flag" class="size-4" /> Meilensteine
            </.link>
          </div>
        </div>
      </div>

      <%!-- Tabs --%>
      <div class="tabs tabs-bordered">
        <button
          class={["tab gap-2", @active_tab == :comments && "tab-active"]}
          phx-click="set_tab"
          phx-value-tab="comments"
        >
          <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" /> Kommentare
        </button>
        <button
          class={["tab gap-2", @active_tab == :attachments && "tab-active"]}
          phx-click="set_tab"
          phx-value-tab="attachments"
        >
          <.icon name="hero-paper-clip" class="size-4" /> Anhänge
        </button>
      </div>

      <%!-- Tab-Inhalt --%>
      <div class="bg-base-100 border border-base-300 rounded-box p-6">
        <.live_component
          :if={@active_tab == :comments}
          module={TaskboardWeb.CommentThreadComponent}
          id={"comments-project-#{@project.id}"}
          parent_type={:project}
          parent_id={@project.id}
          current_user={@current_user}
        />
        <.live_component
          :if={@active_tab == :attachments}
          module={TaskboardWeb.AttachmentPanelComponent}
          id={"attachments-project-#{@project.id}"}
          parent_type={:project}
          parent_id={@project.id}
          current_user={@current_user}
        />
      </div>
    </div>
    """
  end

  defp load_project(id, actor) do
    Taskboard.Projects.Project
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.limit(1)
    |> Ash.read_one(actor: actor)
  end

  defp status_label(:draft), do: "Entwurf"
  defp status_label(:active), do: "Aktiv"
  defp status_label(:paused), do: "Pausiert"
  defp status_label(:completed), do: "Abgeschlossen"
  defp status_label(:archived), do: "Archiviert"
  defp status_label(other), do: to_string(other)

  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:paused), do: "badge-warning"
  defp status_badge_class(:completed), do: "badge-info"
  defp status_badge_class(:archived), do: "badge-neutral"
  defp status_badge_class(_), do: "badge-ghost"

  defp status_icon_bg(:active), do: "bg-success/15"
  defp status_icon_bg(:paused), do: "bg-warning/15"
  defp status_icon_bg(:completed), do: "bg-info/15"
  defp status_icon_bg(_), do: "bg-base-300"

  defp status_icon_color(:active), do: "text-success"
  defp status_icon_color(:paused), do: "text-warning"
  defp status_icon_color(:completed), do: "text-info"
  defp status_icon_color(_), do: "text-base-content/50"
end
