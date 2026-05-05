defmodule TaskboardWeb.AttachmentPanelComponent do
  @moduledoc false
  use TaskboardWeb, :live_component

  require Ash.Query

  alias Taskboard.Projects.{Attachment, Storage}

  @impl true
  def mount(socket) do
    max_bytes = Application.get_env(:taskboard, :upload_max_bytes, 10 * 1024 * 1024)

    {:ok,
     socket
     |> allow_upload(:attachment,
       accept: :any,
       max_entries: 5,
       max_file_size: max_bytes
     )
     |> assign(:description, "")}
  end

  @impl true
  def update(assigns, socket) do
    attachments = load_attachments(assigns.parent_type, assigns.parent_id, assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:attachments, attachments)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_description", %{"description" => desc}, socket) do
    {:noreply, assign(socket, :description, desc)}
  end

  @impl true
  def handle_event("save_attachment", _params, socket) do
    current_user = socket.assigns.current_user
    parent_type = socket.assigns.parent_type
    parent_id = socket.assigns.parent_id
    description = socket.assigns.description

    results =
      consume_uploaded_entries(socket, :attachment, fn %{path: tmp_path}, entry ->
        binary = File.read!(tmp_path)

        case Storage.save(binary, entry.client_name) do
          {:ok, storage_path} ->
            attrs =
              %{
                filename: entry.client_name,
                content_type: entry.client_type || "application/octet-stream",
                size_bytes: entry.client_size,
                storage_path: storage_path,
                description: if(description == "", do: nil, else: description),
                uploaded_by_id: current_user.id
              }
              |> Map.put(parent_key(parent_type), parent_id)

            persist_attachment(attrs, storage_path, current_user)

          {:error, _} ->
            {:postpone, :error}
        end
      end)

    if Enum.all?(results, &(&1 == :uploaded)) do
      attachments = load_attachments(parent_type, parent_id, current_user)
      {:noreply, assign(socket, attachments: attachments, description: "")}
    else
      {:noreply,
       put_flash(socket, :error, "Mindestens eine Datei konnte nicht hochgeladen werden.")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachment, ref)}
  end

  @impl true
  def handle_event("delete_attachment", %{"id" => id}, socket) do
    with {:ok, attachment} <- Ash.get(Attachment, id, actor: socket.assigns.current_user),
         :ok <- Storage.delete(attachment.storage_path),
         :ok <- Ash.destroy(attachment, actor: socket.assigns.current_user) do
      attachments =
        load_attachments(
          socket.assigns.parent_type,
          socket.assigns.parent_id,
          socket.assigns.current_user
        )

      {:noreply, assign(socket, :attachments, attachments)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Datei konnte nicht gelöscht werden.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <h3 class="font-semibold text-base-content/80 flex items-center gap-2">
        <.icon name="hero-paper-clip" class="size-4" /> Anhänge
        <span class="badge badge-ghost badge-sm">{length(@attachments)}</span>
      </h3>

      <%!-- Dateiliste --%>
      <div :if={@attachments == []} class="text-sm text-base-content/40 italic py-2">
        Noch keine Anhänge.
      </div>

      <div :if={@attachments != []} class="flex flex-col divide-y divide-base-200">
        <div :for={attachment <- @attachments} class="flex items-center gap-3 py-2 group">
          <.icon
            name={file_icon(attachment.content_type)}
            class="size-5 text-base-content/40 shrink-0"
          />
          <div class="flex-1 min-w-0">
            <a
              href={"/attachments/#{attachment.id}/download"}
              class="text-sm font-medium hover:text-primary truncate block"
              download={attachment.filename}
            >
              {attachment.filename}
            </a>
            <div class="text-xs text-base-content/40 flex gap-2">
              <span>{format_bytes(attachment.size_bytes)}</span>
              <span>·</span>
              <span>{uploader_name(attachment.uploaded_by)}</span>
              <span>·</span>
              <span>{format_date(attachment.inserted_at)}</span>
              <span :if={attachment.description} class="truncate">· {attachment.description}</span>
            </div>
          </div>
          <button
            :if={attachment.uploaded_by_id == @current_user.id}
            class="opacity-0 group-hover:opacity-100 transition-opacity text-base-content/30 hover:text-error"
            phx-click="delete_attachment"
            phx-value-id={attachment.id}
            phx-target={@myself}
            data-confirm={"#{attachment.filename} löschen?"}
          >
            <.icon name="hero-trash" class="size-4" />
          </button>
        </div>
      </div>

      <%!-- Upload-Formular --%>
      <form phx-submit="save_attachment" phx-change="validate" phx-target={@myself}>
        <div class="border-2 border-dashed border-base-300 rounded-box p-4 flex flex-col gap-3">
          <div class="flex items-center gap-2 text-sm text-base-content/50">
            <.icon name="hero-arrow-up-tray" class="size-4" />
            <.live_file_input
              upload={@uploads.attachment}
              class="file-input file-input-bordered file-input-sm flex-1"
            />
          </div>

          <div :for={entry <- @uploads.attachment.entries} class="flex items-center gap-2 text-sm">
            <.icon name="hero-document" class="size-4 text-base-content/40" />
            <span class="flex-1 truncate">{entry.client_name}</span>
            <span class="text-base-content/40">{format_bytes(entry.client_size)}</span>
            <div class="w-16">
              <progress class="progress progress-primary w-full" value={entry.progress} max="100" />
            </div>
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              phx-target={@myself}
              class="text-base-content/30 hover:text-error"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>

          <div :for={err <- upload_errors(@uploads.attachment)} class="text-error text-xs">
            {upload_error_message(err)}
          </div>

          <div :if={@uploads.attachment.entries != []} class="flex items-center gap-2">
            <input
              type="text"
              name="description"
              placeholder="Optionale Beschreibung…"
              class="input input-bordered input-sm flex-1"
              value={@description}
              phx-change="update_description"
              phx-target={@myself}
            />
            <button
              type="submit"
              class="btn btn-primary btn-sm"
              disabled={@uploads.attachment.entries == []}
            >
              Hochladen
            </button>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp load_attachments(:project, parent_id, actor) do
    Attachment
    |> Ash.Query.filter(project_id == ^parent_id)
    |> Ash.Query.load([:uploaded_by])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: actor)
  rescue
    _ -> []
  end

  defp load_attachments(:project_task, parent_id, actor) do
    Attachment
    |> Ash.Query.filter(project_task_id == ^parent_id)
    |> Ash.Query.load([:uploaded_by])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: actor)
  rescue
    _ -> []
  end

  defp persist_attachment(attrs, storage_path, current_user) do
    case Ash.create(Attachment, attrs, actor: current_user) do
      {:ok, _} ->
        {:ok, :uploaded}

      {:error, _} ->
        Storage.delete(storage_path)
        {:postpone, :error}
    end
  end

  defp parent_key(:project), do: :project_id
  defp parent_key(:project_task), do: :project_task_id

  defp uploader_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp uploader_name(%{email: email}), do: to_string(email)
  defp uploader_name(_), do: "Unbekannt"

  defp format_bytes(nil), do: ""
  defp format_bytes(bytes) when bytes < 1_024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{round(bytes / 1_024)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_date(nil), do: ""

  defp format_date(dt) do
    Calendar.strftime(dt, "%d.%m.%Y")
  rescue
    _ -> ""
  end

  defp file_icon("image/" <> _), do: "hero-photo"
  defp file_icon("application/pdf"), do: "hero-document-text"
  defp file_icon("text/" <> _), do: "hero-document-text"
  defp file_icon(_), do: "hero-document"

  defp upload_error_message(:too_large), do: "Datei ist zu groß (max. 10 MB)"
  defp upload_error_message(:not_accepted), do: "Dateityp nicht erlaubt"
  defp upload_error_message(:too_many_files), do: "Zu viele Dateien (max. 5)"
  defp upload_error_message(_), do: "Upload-Fehler"
end
