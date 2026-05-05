defmodule Taskboard.Projects.Storage do
  @moduledoc false

  @doc """
  Saves a binary to disk under a unique path derived from `filename`.
  Returns `{:ok, storage_path}` where `storage_path` is relative to the
  configured upload root (suitable for storing in the database).
  """
  def save(binary, original_filename) do
    ext = Path.extname(original_filename)
    unique_name = "#{Ecto.UUID.generate()}#{ext}"
    rel_path = Path.join(date_prefix(), unique_name)
    abs_path = absolute_path(rel_path)

    with :ok <- File.mkdir_p(Path.dirname(abs_path)),
         :ok <- File.write(abs_path, binary) do
      {:ok, rel_path}
    end
  end

  @doc "Deletes the file at the given relative storage path."
  def delete(storage_path) do
    case File.rm(abs(storage_path)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns the absolute filesystem path for a stored file."
  def absolute_path(rel_path), do: Path.join(upload_root(), rel_path)

  defp upload_root, do: Application.fetch_env!(:taskboard, :upload_root)

  defp date_prefix do
    {year, month, _day} = Date.utc_today() |> Date.to_erl()
    "#{year}/#{String.pad_leading(to_string(month), 2, "0")}"
  end
end
