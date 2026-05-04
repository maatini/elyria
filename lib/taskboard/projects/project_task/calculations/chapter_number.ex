defmodule Taskboard.Projects.ProjectTask.Calculations.ChapterNumber do
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:position, :level, parent: [:position]]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn
      %{level: 0, position: pos} -> to_string(pos)
      %{level: 1, position: pos, parent: %{position: parent_pos}} -> "#{parent_pos}.#{pos}"
      %{level: 1, position: pos} -> "?.#{pos}"
    end)
  end
end
