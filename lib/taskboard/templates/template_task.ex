defmodule Taskboard.Templates.TemplateTask do
  @moduledoc false
  use Ash.Resource,
    domain: Taskboard.Templates,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("template_tasks")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)

    # Hierarchy: 0 = chapter/section, 1 = task
    attribute(:level, :integer, default: 0, allow_nil?: false, public?: true)
    # Position within parent (1-indexed)
    attribute(:position, :integer, default: 1, allow_nil?: false, public?: true)

    # Relative time offsets to template reference date (days)
    # Negative = before reference date, positive = after
    attribute(:start_offset_days, :integer, default: 0, public?: true)
    attribute(:end_offset_days, :integer, default: 7, public?: true)
    # Days before end_date to show warning (nil = no warning)
    attribute(:warning_offset_days, :integer, allow_nil?: true, public?: true)

    # JSONB blob for custom field default values: %{"field_name" => value}
    attribute(:custom_field_defaults, :map, default: %{}, public?: true)

    timestamps()
  end

  calculations do
    calculate(
      :chapter_number,
      :string,
      Taskboard.Templates.TemplateTask.Calculations.ChapterNumber
    )
  end

  relationships do
    belongs_to :template, Taskboard.Templates.Template, allow_nil?: false
    belongs_to :parent, Taskboard.Templates.TemplateTask, allow_nil?: true
    has_many :children, Taskboard.Templates.TemplateTask, destination_attribute: :parent_id

    belongs_to :assigned_group, Taskboard.Accounts.Group, allow_nil?: true

    has_many :outgoing_dependencies, Taskboard.Templates.TemplateTaskDependency,
      destination_attribute: :predecessor_id

    has_many :incoming_dependencies, Taskboard.Templates.TemplateTaskDependency,
      destination_attribute: :successor_id
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :title,
        :description,
        :level,
        :position,
        :start_offset_days,
        :end_offset_days,
        :warning_offset_days,
        :custom_field_defaults,
        :template_id,
        :parent_id,
        :assigned_group_id
      ])

      change(Taskboard.Templates.TemplateTask.Changes.EnsureValidLevel)
    end

    update :update do
      accept([
        :title,
        :description,
        :position,
        :start_offset_days,
        :end_offset_days,
        :warning_offset_days,
        :custom_field_defaults,
        :assigned_group_id
      ])

      require_atomic?(false)
    end

    update :reorder do
      accept([:position])
      require_atomic?(false)
    end
  end

  identities do
    identity(:unique_position, [:template_id, :parent_id, :position])
  end
end
