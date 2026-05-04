defmodule Taskboard.Projects.Milestone.Calculations.Warning do
  @moduledoc false
  use Ash.Resource.Calculation

  def load(_query, _opts, _context), do: [:tasks]

  def calculate(milestones, _opts, _context) do
    today = Date.utc_today()

    Enum.map(milestones, fn milestone ->
      tasks = milestone.tasks || []
      fulfilled = tasks != [] and Enum.all?(tasks, &(&1.status in [:done, :skipped]))

      not fulfilled and
        milestone.warning_date != nil and
        Date.compare(milestone.warning_date, today) in [:lt, :eq]
    end)
  end
end
