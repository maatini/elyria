defmodule Taskboard.Projects.ProjectTask.Calculations.Warning do
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:warning_date, :end_date, :status]

  @impl true
  def calculate(records, _opts, _context) do
    today = Date.utc_today()

    Enum.map(records, fn task ->
      task.status not in [:done, :skipped] and
        not is_nil(task.warning_date) and
        Date.compare(task.warning_date, today) != :gt and
        (is_nil(task.end_date) or Date.compare(task.end_date, today) != :lt)
    end)
  end
end
