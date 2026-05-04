defmodule Taskboard.Templates.TemplateMilestone do
  @moduledoc false
  use Ash.Resource,
    domain: Taskboard.Templates,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("template_milestones")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)

    # Days from reference_date → due_date (positive = after reference)
    attribute(:due_offset_days, :integer, allow_nil?: false, default: 30, public?: true)
    # Days before due_date → warning_date (positive = warn N days before due)
    attribute(:warning_offset_days, :integer, allow_nil?: false, default: 7, public?: true)

    timestamps()
  end

  relationships do
    belongs_to(:template, Taskboard.Templates.Template, allow_nil?: false)
    has_many(:template_tasks, Taskboard.Templates.TemplateTask)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :description, :due_offset_days, :warning_offset_days, :template_id])
    end

    update :update do
      accept([:name, :description, :due_offset_days, :warning_offset_days])
      require_atomic?(false)
    end
  end
end
