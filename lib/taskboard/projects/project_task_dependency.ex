defmodule Taskboard.Projects.ProjectTaskDependency do
  use Ash.Resource,
    domain: Taskboard.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("project_task_dependencies")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:type, :atom,
      constraints: [one_of: [:finish_to_start, :start_to_start, :finish_to_finish]],
      default: :finish_to_start,
      public?: true
    )

    attribute(:lag_days, :integer, default: 0, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :predecessor, Taskboard.Projects.ProjectTask, allow_nil?: false
    belongs_to :successor, Taskboard.Projects.ProjectTask, allow_nil?: false
  end

  identities do
    identity(:unique_dependency, [:predecessor_id, :successor_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:predecessor_id, :successor_id, :type, :lag_days])
    end
  end
end
