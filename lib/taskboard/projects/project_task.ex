defmodule Taskboard.Projects.ProjectTask do
  use Ash.Resource,
    domain: Taskboard.Projects,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine]

  state_machine do
    state_attribute(:status)
    # Tasks start as :open (no deps) or :blocked (has deps) at activation time
    initial_states([:open, :blocked])
    default_initial_state(:open)

    transitions do
      transition(:unblock, from: :blocked, to: :open)
      transition(:start, from: :open, to: :in_progress)
      transition(:complete, from: [:open, :in_progress], to: :done)
      transition(:skip, from: [:open, :in_progress, :blocked], to: :skipped)
      transition(:reopen, from: [:done, :skipped], to: :open)
      transition(:block, from: :open, to: :blocked)
    end
  end

  postgres do
    table("project_tasks")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)

    attribute(:level, :integer, default: 0, allow_nil?: false, public?: true)
    attribute(:position, :integer, default: 1, allow_nil?: false, public?: true)

    attribute(:start_date, :date, public?: true)
    attribute(:end_date, :date, public?: true)
    attribute(:warning_date, :date, allow_nil?: true, public?: true)
    attribute(:completed_at, :utc_datetime_usec, allow_nil?: true, public?: true)

    # Custom field values: %{"field_name" => value}
    attribute(:custom_field_values, :map, default: %{}, public?: true)
    attribute(:notes, :string, public?: true)

    timestamps()
  end

  calculations do
    calculate(:chapter_number, :string, Taskboard.Projects.ProjectTask.Calculations.ChapterNumber)
    calculate(:overdue?, :boolean, Taskboard.Projects.ProjectTask.Calculations.Overdue)
    calculate(:warning?, :boolean, Taskboard.Projects.ProjectTask.Calculations.Warning)
  end

  relationships do
    belongs_to :project, Taskboard.Projects.Project, allow_nil?: false
    belongs_to :parent, Taskboard.Projects.ProjectTask, allow_nil?: true
    has_many :children, Taskboard.Projects.ProjectTask, destination_attribute: :parent_id

    belongs_to :assigned_group, Taskboard.Accounts.Group, allow_nil?: true

    # Link back to the template task it was created from
    belongs_to :template_task, Taskboard.Templates.TemplateTask, allow_nil?: true

    has_many :outgoing_dependencies, Taskboard.Projects.ProjectTaskDependency,
      destination_attribute: :predecessor_id

    has_many :incoming_dependencies, Taskboard.Projects.ProjectTaskDependency,
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
        :status,
        :start_date,
        :end_date,
        :warning_date,
        :custom_field_values,
        :notes,
        :project_id,
        :parent_id,
        :template_task_id,
        :assigned_group_id
      ])
    end

    update :update do
      accept([
        :title,
        :description,
        :start_date,
        :end_date,
        :warning_date,
        :custom_field_values,
        :notes,
        :assigned_group_id
      ])

      require_atomic?(false)
    end

    update :complete do
      accept([])
      require_atomic?(false)
      change(set_attribute(:completed_at, &DateTime.utc_now/0))
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :done})
    end

    update :unblock do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :open})
    end

    update :start do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :in_progress})
    end

    update :skip do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :skipped})
    end

    update :reopen do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :open})
    end

    update :block do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :blocked})
    end

    read :my_tasks do
      filter(
        expr(
          status in [:open, :in_progress] and
            not is_nil(assigned_group_id) and
            assigned_group.group_memberships.user_id == ^actor(:id)
        )
      )

      prepare(build(sort: [end_date: :asc_nils_last]))
    end
  end

  # Propagate status to successor tasks after status transitions to :done or :skipped
  changes do
    change(Taskboard.Projects.ProjectTask.Changes.PropagateStatusToSuccessors,
      on: [:update]
    )
  end
end
