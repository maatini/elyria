defmodule TaskboardWeb.AttachmentController do
  use TaskboardWeb, :controller

  alias Taskboard.Projects.{Attachment, Storage}

  def download(conn, %{"id" => id}) do
    case Ash.get(Attachment, id, actor: conn.assigns.current_user) do
      {:ok, attachment} ->
        abs_path = Storage.absolute_path(attachment.storage_path)

        if File.exists?(abs_path) do
          send_download(conn, {:file, abs_path},
            filename: attachment.filename,
            content_type: attachment.content_type,
            disposition: :attachment
          )
        else
          conn
          |> put_status(:not_found)
          |> put_view(TaskboardWeb.ErrorHTML)
          |> render(:"404")
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> put_view(TaskboardWeb.ErrorHTML)
        |> render(:"404")
    end
  end
end
