defmodule Taskboard.Projects.Milestone do
  @moduledoc false
  use Ash.Resource,
    domain: Taskboard.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("milestones")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:due_date, :date, allow_nil?: false, public?: true)
    attribute(:warning_date, :date, allow_nil?: false, public?: true)

    timestamps()
  end

  calculations do
    calculate(:fulfilled?, :boolean, Taskboard.Projects.Milestone.Calculations.Fulfilled)
    calculate(:overdue?, :boolean, Taskboard.Projects.Milestone.Calculations.Overdue)
    calculate(:warning?, :boolean, Taskboard.Projects.Milestone.Calculations.Warning)
  end

  relationships do
    belongs_to(:project, Taskboard.Projects.Project, allow_nil?: false)

    belongs_to(:template_milestone, Taskboard.Templates.TemplateMilestone, allow_nil?: true)

    has_many(:tasks, Taskboard.Projects.ProjectTask)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :name,
        :description,
        :due_date,
        :warning_date,
        :project_id,
        :template_milestone_id
      ])

      validate(compare(:warning_date, less_than_or_equal_to: :due_date),
        message: "Warndatum muss vor dem Fälligkeitsdatum liegen"
      )
    end

    update :update do
      accept([:name, :description, :due_date, :warning_date])
      require_atomic?(false)

      validate(compare(:warning_date, less_than_or_equal_to: :due_date),
        message: "Warndatum muss vor dem Fälligkeitsdatum liegen"
      )
    end

    read :for_project do
      argument(:project_id, :uuid, allow_nil?: false)
      filter(expr(project_id == ^arg(:project_id)))
      prepare(build(sort: [due_date: :asc]))
    end
  end
end
