defmodule Taskboard.Projects.Milestone.Calculations.Fulfilled do
  @moduledoc false
  use Ash.Resource.Calculation

  def load(_query, _opts, _context), do: [:tasks]

  def calculate(milestones, _opts, _context) do
    Enum.map(milestones, fn milestone ->
      tasks = milestone.tasks || []
      tasks != [] and Enum.all?(tasks, &(&1.status in [:done, :skipped]))
    end)
  end
end
