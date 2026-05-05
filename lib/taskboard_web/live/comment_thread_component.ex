defmodule TaskboardWeb.CommentThreadComponent do
  @moduledoc false
  use TaskboardWeb, :live_component

  require Ash.Query

  alias Taskboard.Projects.Comment

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :body, "")}
  end

  @impl true
  def update(assigns, socket) do
    comments = load_comments(assigns.parent_type, assigns.parent_id, assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:comments, comments)}
  end

  @impl true
  def handle_event("update_body", %{"body" => body}, socket) do
    {:noreply, assign(socket, :body, body)}
  end

  @impl true
  def handle_event("add_comment", %{"body" => body}, socket) when byte_size(body) == 0 do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_comment", %{"body" => body}, socket) do
    attrs =
      %{body: body, author_id: socket.assigns.current_user.id}
      |> Map.put(parent_key(socket.assigns.parent_type), socket.assigns.parent_id)

    case Ash.create(Comment, attrs, actor: socket.assigns.current_user) do
      {:ok, _} ->
        comments =
          load_comments(
            socket.assigns.parent_type,
            socket.assigns.parent_id,
            socket.assigns.current_user
          )

        {:noreply, assign(socket, comments: comments, body: "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kommentar konnte nicht gespeichert werden.")}
    end
  end

  @impl true
  def handle_event("delete_comment", %{"id" => id}, socket) do
    with {:ok, comment} <- Ash.get(Comment, id, actor: socket.assigns.current_user),
         :ok <- Ash.destroy(comment, actor: socket.assigns.current_user) do
      comments =
        load_comments(
          socket.assigns.parent_type,
          socket.assigns.parent_id,
          socket.assigns.current_user
        )

      {:noreply, assign(socket, :comments, comments)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Kommentar konnte nicht gelöscht werden.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <h3 class="font-semibold text-base-content/80 flex items-center gap-2">
        <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" /> Kommentare
        <span class="badge badge-ghost badge-sm">{length(@comments)}</span>
      </h3>

      <div :if={@comments == []} class="text-sm text-base-content/40 italic py-2">
        Noch keine Kommentare.
      </div>

      <div class="flex flex-col gap-3">
        <div :for={comment <- @comments} class="flex gap-3 group">
          <div class="size-8 rounded-full bg-primary/15 flex items-center justify-center shrink-0 text-xs font-bold text-primary">
            {initials(comment.author)}
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-baseline gap-2">
              <span class="font-medium text-sm">{author_name(comment.author)}</span>
              <span class="text-xs text-base-content/40">
                {format_datetime(comment.inserted_at)}
              </span>
              <button
                :if={comment.author_id == @current_user.id}
                class="ml-auto opacity-0 group-hover:opacity-100 transition-opacity text-base-content/30 hover:text-error"
                phx-click="delete_comment"
                phx-value-id={comment.id}
                phx-target={@myself}
                data-confirm="Kommentar löschen?"
              >
                <.icon name="hero-trash" class="size-3.5" />
              </button>
            </div>
            <p class="text-sm text-base-content/80 whitespace-pre-wrap break-words mt-0.5">
              {comment.body}
            </p>
          </div>
        </div>
      </div>

      <form phx-submit="add_comment" phx-target={@myself} class="flex gap-2 mt-1">
        <textarea
          name="body"
          rows="2"
          placeholder="Kommentar schreiben…"
          class="textarea textarea-bordered textarea-sm flex-1 resize-none"
          phx-change="update_body"
          phx-target={@myself}
          value={@body}
        />
        <button
          type="submit"
          class="btn btn-primary btn-sm self-end"
          disabled={@body == ""}
        >
          <.icon name="hero-paper-airplane" class="size-4" />
        </button>
      </form>
    </div>
    """
  end

  defp load_comments(:project, parent_id, actor) do
    Comment
    |> Ash.Query.filter(project_id == ^parent_id)
    |> Ash.Query.load([:author])
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(actor: actor)
  rescue
    _ -> []
  end

  defp load_comments(:project_task, parent_id, actor) do
    Comment
    |> Ash.Query.filter(project_task_id == ^parent_id)
    |> Ash.Query.load([:author])
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(actor: actor)
  rescue
    _ -> []
  end

  defp parent_key(:project), do: :project_id
  defp parent_key(:project_task), do: :project_task_id

  defp author_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp author_name(%{email: email}), do: to_string(email)
  defp author_name(_), do: "Unbekannt"

  defp initials(user) do
    case author_name(user) do
      name when is_binary(name) ->
        name
        |> String.split()
        |> Enum.take(2)
        |> Enum.map_join("", &String.first/1)
        |> String.upcase()

      _ ->
        "?"
    end
  end

  defp format_datetime(nil), do: ""

  defp format_datetime(dt) do
    dt
    |> DateTime.shift_zone!("Europe/Berlin")
    |> Calendar.strftime("%d.%m.%Y %H:%M")
  rescue
    _ -> Calendar.strftime(dt, "%d.%m.%Y %H:%M")
  end
end
