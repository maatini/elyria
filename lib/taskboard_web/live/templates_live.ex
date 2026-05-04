defmodule TaskboardWeb.TemplatesLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    templates = load_templates(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Vorlagen")
     |> assign(:templates, templates)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-5xl mx-auto">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">Vorlagen</h1>
        <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm">
          <.icon name="hero-pencil-square" class="size-4" /> Admin
        </.link>
      </div>

      <div :if={@templates == []} class="text-center py-16 text-base-content/40">
        <p>Noch keine Vorlagen vorhanden.</p>
        <.link navigate={~p"/admin"} class="btn btn-primary btn-sm mt-4">
          Vorlage erstellen
        </.link>
      </div>

      <div class="grid gap-4">
        <div
          :for={template <- @templates}
          class="card bg-base-200 shadow-sm hover:shadow-md transition-shadow"
        >
          <div class="card-body py-4">
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <h2 class="card-title text-base truncate">{template.name}</h2>
                <p :if={template.description} class="text-sm text-base-content/60 mt-1">
                  {template.description}
                </p>
                <div class="flex flex-wrap gap-2 mt-2">
                  <span class={["badge badge-sm", status_badge_class(template.status)]}>
                    {status_label(template.status)}
                  </span>
                  <span :if={template.family} class="badge badge-ghost badge-sm">
                    {template.family}
                  </span>
                  <span
                    :for={ct <- template.allowed_context_types}
                    class="badge badge-outline badge-sm"
                  >
                    {ct}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_templates(actor) do
    Taskboard.Templates.Template
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  rescue
    _ -> []
  end

  defp status_label(:draft), do: "Entwurf"
  defp status_label(:active), do: "Aktiv"
  defp status_label(:archived), do: "Archiviert"
  defp status_label(other), do: to_string(other)

  defp status_badge_class(:draft), do: "badge-ghost"
  defp status_badge_class(:active), do: "badge-success"
  defp status_badge_class(:archived), do: "badge-neutral"
  defp status_badge_class(_), do: "badge-ghost"
end
