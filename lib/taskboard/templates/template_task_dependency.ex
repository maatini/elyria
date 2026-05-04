defmodule Taskboard.Templates.TemplateTaskDependency do
  use Ash.Resource,
    domain: Taskboard.Templates,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("template_task_dependencies")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # finish_to_start: successor can't start until predecessor finishes (default)
    # start_to_start: successor can't start until predecessor starts
    # finish_to_finish: successor can't finish until predecessor finishes
    attribute(:type, :atom,
      constraints: [one_of: [:finish_to_start, :start_to_start, :finish_to_finish]],
      default: :finish_to_start,
      public?: true
    )

    attribute(:lag_days, :integer, default: 0, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :predecessor, Taskboard.Templates.TemplateTask, allow_nil?: false
    belongs_to :successor, Taskboard.Templates.TemplateTask, allow_nil?: false
  end

  identities do
    identity(:unique_dependency, [:predecessor_id, :successor_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:predecessor_id, :successor_id, :type, :lag_days])
      change(Taskboard.Templates.TemplateTaskDependency.Changes.PreventCircularDependency)
    end
  end
end
