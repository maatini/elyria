defmodule TaskboardWeb.TemplatesLive do
  use TaskboardWeb, :live_view

  require Ash.Query

  alias Taskboard.Templates.Template

  @context_types [
    market: "Markt",
    plant: "Werk",
    building: "Gebäude",
    customer_project: "Kundenprojekt",
    department: "Abteilung",
    it_project: "IT-Projekt",
    hr_project: "HR-Projekt",
    facility: "Facility",
    generic: "Allgemein"
  ]

  @impl true
  def mount(_params, _session, socket) do
    templates = load_templates(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Vorlagen")
     |> assign(:templates, templates)
     |> assign(:context_types, @context_types)
     |> assign(:modal, nil)
     |> assign(:form_errors, [])}
  end

  @impl true
  def handle_event("new_template", _params, socket) do
    {:noreply, assign(socket, :modal, {:new, empty_form()})}
  end

  @impl true
  def handle_event("edit_template", %{"id" => id}, socket) do
    case find_template(socket.assigns.templates, id) do
      nil -> {:noreply, socket}
      template -> {:noreply, assign(socket, :modal, {:edit, template, prefill(template)})}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form_errors: [])}
  end

  @impl true
  def handle_event("save_template", %{"template" => params}, socket) do
    attrs = parse_attrs(params)

    result =
      case socket.assigns.modal do
        {:new, _} ->
          Ash.create(Template, attrs, actor: socket.assigns.current_user)

        {:edit, template, _} ->
          Ash.update(template, attrs, action: :update, actor: socket.assigns.current_user)
      end

    case result do
      {:ok, _} ->
        templates = load_templates(socket.assigns.current_user)
        {:noreply, assign(socket, templates: templates, modal: nil, form_errors: [])}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        {:noreply, assign(socket, :form_errors, format_errors(errors))}

      {:error, _} ->
        {:noreply, assign(socket, :form_errors, ["Unbekannter Fehler"])}
    end
  end

  @impl true
  def handle_event("publish_template", %{"id" => id}, socket) do
    run_transition(id, :publish, socket)
  end

  @impl true
  def handle_event("archive_template", %{"id" => id}, socket) do
    run_transition(id, :archive, socket)
  end

  @impl true
  def handle_event("restore_template", %{"id" => id}, socket) do
    run_transition(id, :restore, socket)
  end

  @impl true
  def handle_event("delete_template", %{"id" => id}, socket) do
    case find_template(socket.assigns.templates, id) do
      nil ->
        {:noreply, socket}

      template ->
        case Ash.destroy(template, actor: socket.assigns.current_user) do
          :ok ->
            templates = load_templates(socket.assigns.current_user)
            {:noreply, assign(socket, :templates, templates)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Vorlage konnte nicht gelöscht werden.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Header --%>
    <div class="bg-gradient-to-br from-accent/8 via-base-100 to-base-100 border-b border-base-300 px-8 py-8">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold tracking-tight">Vorlagen</h1>
          <p class="text-base-content/60 mt-1 text-sm">
            <span class="font-medium text-base-content/80">{length(@templates)}</span> Vorlagen
          </p>
        </div>
        <button class="btn btn-primary gap-2" phx-click="new_template">
          <.icon name="hero-plus" class="size-4" /> Neue Vorlage
        </button>
      </div>
    </div>

    <div class="p-6 max-w-5xl">
      <%!-- Leer-Zustand --%>
      <div :if={@templates == []} class="flex flex-col items-center justify-center py-24 text-center">
        <div class="size-16 rounded-full bg-base-300 flex items-center justify-center mb-4">
          <.icon name="hero-document-duplicate" class="size-8 text-base-content/30" />
        </div>
        <h3 class="text-lg font-semibold text-base-content/60">Noch keine Vorlagen</h3>
        <button class="btn btn-primary btn-sm mt-4" phx-click="new_template">
          Erste Vorlage erstellen
        </button>
      </div>

      <%!-- Template-Liste --%>
      <div class="grid gap-3">
        <div
          :for={template <- @templates}
          class="card bg-base-200 border border-base-300 hover:shadow-md transition-shadow"
        >
          <div class="card-body py-4 px-5">
            <div class="flex items-start gap-4">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <h2 class="font-semibold text-base">{template.name}</h2>
                  <span class={["badge badge-sm", status_badge_class(template.status)]}>
                    {status_label(template.status)}
                  </span>
                  <span :if={template.family} class="badge badge-ghost badge-sm">
                    {template.family}
                  </span>
                </div>
                <p :if={template.description} class="text-sm text-base-content/60 mt-1 truncate">
                  {template.description}
                </p>
                <div class="flex flex-wrap gap-1 mt-2">
                  <span
                    :for={ct <- template.allowed_context_types}
                    class="badge badge-outline badge-xs"
                  >
                    {context_type_label(ct, @context_types)}
                  </span>
                </div>
              </div>

              <%!-- Aktionen --%>
              <div class="flex items-center gap-1 shrink-0">
                <.link
                  navigate={~p"/templates/#{template.id}"}
                  class="btn btn-ghost btn-sm gap-1"
                  title="Aufgaben bearbeiten"
                >
                  <.icon name="hero-list-bullet" class="size-4" />
                </.link>

                <button
                  :if={template.status == :draft}
                  class="btn btn-ghost btn-sm"
                  title="Bearbeiten"
                  phx-click="edit_template"
                  phx-value-id={template.id}
                >
                  <.icon name="hero-pencil" class="size-4" />
                </button>

                <button
                  :if={template.status == :draft}
                  class="btn btn-success btn-sm gap-1"
                  title="Veröffentlichen"
                  phx-click="publish_template"
                  phx-value-id={template.id}
                  data-confirm="Vorlage veröffentlichen?"
                >
                  <.icon name="hero-check" class="size-4" /> Veröffentlichen
                </button>

                <button
                  :if={template.status == :active}
                  class="btn btn-ghost btn-sm"
                  title="Bearbeiten"
                  phx-click="edit_template"
                  phx-value-id={template.id}
                >
                  <.icon name="hero-pencil" class="size-4" />
                </button>

                <button
                  :if={template.status == :active}
                  class="btn btn-warning btn-sm gap-1"
                  title="Archivieren"
                  phx-click="archive_template"
                  phx-value-id={template.id}
                  data-confirm="Vorlage archivieren?"
                >
                  <.icon name="hero-archive-box" class="size-4" /> Archivieren
                </button>

                <button
                  :if={template.status == :archived}
                  class="btn btn-ghost btn-sm gap-1"
                  title="Wiederherstellen"
                  phx-click="restore_template"
                  phx-value-id={template.id}
                >
                  <.icon name="hero-arrow-path" class="size-4" /> Wiederherstellen
                </button>

                <button
                  :if={template.status == :draft}
                  class="btn btn-ghost btn-sm text-error"
                  title="Löschen"
                  phx-click="delete_template"
                  phx-value-id={template.id}
                  data-confirm={"Vorlage \"#{template.name}\" unwiderruflich löschen?"}
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <%!-- Erstellen/Bearbeiten-Modal --%>
    <dialog :if={@modal} id="template-modal" class="modal modal-open">
      <div class="modal-box w-full max-w-lg">
        <h3 class="font-bold text-lg mb-5">
          {if match?({:new, _}, @modal), do: "Neue Vorlage", else: "Vorlage bearbeiten"}
        </h3>

        <div :if={@form_errors != []} class="alert alert-error mb-4">
          <.icon name="hero-exclamation-circle" class="size-4" />
          <ul class="list-disc list-inside text-sm">
            <li :for={err <- @form_errors}>{err}</li>
          </ul>
        </div>

        <form phx-submit="save_template" class="flex flex-col gap-4">
          <fieldset class="fieldset">
            <legend class="fieldset-legend">Name *</legend>
            <input
              type="text"
              name="template[name]"
              class="input input-bordered w-full"
              value={form_value(@modal, :name)}
              required
              autofocus
            />
          </fieldset>

          <fieldset class="fieldset">
            <legend class="fieldset-legend">Beschreibung</legend>
            <textarea
              name="template[description]"
              class="textarea textarea-bordered w-full"
              rows="2"
            >{form_value(@modal, :description)}</textarea>
          </fieldset>

          <div class="grid grid-cols-2 gap-4">
            <fieldset class="fieldset">
              <legend class="fieldset-legend">Familie</legend>
              <input
                type="text"
                name="template[family]"
                class="input input-bordered w-full"
                placeholder="z.B. Neueröffnung"
                value={form_value(@modal, :family)}
              />
            </fieldset>

            <fieldset class="fieldset">
              <legend class="fieldset-legend">Referenzdatum-Label</legend>
              <input
                type="text"
                name="template[reference_date_label]"
                class="input input-bordered w-full"
                placeholder="Referenzdatum"
                value={form_value(@modal, :reference_date_label)}
              />
            </fieldset>
          </div>

          <fieldset class="fieldset">
            <legend class="fieldset-legend">Context-Typen</legend>
            <div class="grid grid-cols-2 gap-1">
              <label
                :for={{type, label} <- @context_types}
                class="flex items-center gap-2 cursor-pointer py-1"
              >
                <input
                  type="checkbox"
                  name="template[allowed_context_types][]"
                  value={type}
                  class="checkbox checkbox-sm"
                  checked={type in form_context_types(@modal)}
                />
                <span class="text-sm">{label}</span>
              </label>
            </div>
          </fieldset>

          <div class="modal-action mt-2">
            <button type="button" class="btn btn-ghost" phx-click="close_modal">
              Abbrechen
            </button>
            <button type="submit" class="btn btn-primary">
              Speichern
            </button>
          </div>
        </form>
      </div>
      <div class="modal-backdrop" phx-click="close_modal"></div>
    </dialog>
    """
  end

  # --- Helpers ---

  defp run_transition(id, action, socket) do
    case find_template(socket.assigns.templates, id) do
      nil ->
        {:noreply, socket}

      template ->
        case Ash.update(template, %{}, action: action, actor: socket.assigns.current_user) do
          {:ok, _} ->
            templates = load_templates(socket.assigns.current_user)
            {:noreply, assign(socket, :templates, templates)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Statuswechsel fehlgeschlagen.")}
        end
    end
  end

  defp load_templates(actor) do
    Template
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  rescue
    _ -> []
  end

  defp find_template(templates, id), do: Enum.find(templates, &(&1.id == id))

  defp parse_attrs(params) do
    context_types =
      params
      |> Map.get("allowed_context_types", [])
      |> List.wrap()
      |> Enum.map(&String.to_existing_atom/1)

    %{
      name: params["name"] || "",
      description: nil_if_blank(params["description"]),
      family: nil_if_blank(params["family"]),
      reference_date_label: nil_if_blank(params["reference_date_label"]),
      allowed_context_types: context_types
    }
  end

  defp nil_if_blank(nil), do: nil
  defp nil_if_blank(""), do: nil
  defp nil_if_blank(s), do: s

  defp empty_form,
    do: %{
      name: "",
      description: nil,
      family: nil,
      reference_date_label: "Referenzdatum",
      allowed_context_types: [:generic]
    }

  defp prefill(template) do
    %{
      name: template.name,
      description: template.description,
      family: template.family,
      reference_date_label: template.reference_date_label,
      allowed_context_types: template.allowed_context_types
    }
  end

  defp form_value({:new, form}, field), do: Map.get(form, field, "")
  defp form_value({:edit, _, form}, field), do: Map.get(form, field, "")

  defp form_context_types({:new, form}), do: Map.get(form, :allowed_context_types, [:generic])
  defp form_context_types({:edit, _, form}), do: Map.get(form, :allowed_context_types, [])

  defp format_errors(errors) do
    Enum.map(errors, fn
      %{field: field, message: msg} -> "#{field}: #{msg}"
      %{message: msg} -> msg
      err -> inspect(err)
    end)
  end

  defp context_type_label(type, context_types) do
    Keyword.get(context_types, type, to_string(type))
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
