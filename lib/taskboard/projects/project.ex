defmodule Taskboard.Projects.Project do
  @moduledoc false
  use Ash.Resource,
    domain: Taskboard.Projects,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine]

  state_machine do
    state_attribute(:status)
    initial_states([:draft])
    default_initial_state(:draft)

    transitions do
      transition(:start, from: :draft, to: :active)
      transition(:pause, from: :active, to: :paused)
      transition(:resume, from: :paused, to: :active)
      transition(:complete, from: [:active, :paused], to: :completed)
      transition(:archive, from: [:draft, :active, :paused, :completed], to: :archived)
    end
  end

  postgres do
    table("projects")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:reference_date, :date, allow_nil?: false, public?: true)
    attribute(:activated_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :context, Taskboard.Projects.Context, allow_nil?: false
    belongs_to :project_type, Taskboard.Projects.ProjectType, allow_nil?: true
    belongs_to :template, Taskboard.Templates.Template, allow_nil?: true
    has_many :tasks, Taskboard.Projects.ProjectTask
  end

  actions do
    defaults([:read, :destroy])

    create :activate do
      argument(:template_id, :uuid, allow_nil?: false)
      argument(:context_id, :uuid, allow_nil?: false)
      argument(:reference_date, :date, allow_nil?: false)
      argument(:name, :string, allow_nil?: true)
      argument(:project_type_id, :uuid, allow_nil?: true)

      accept([])
      change(Taskboard.Projects.Project.Changes.Activate)
    end

    update :update do
      accept([:name, :description])
      require_atomic?(false)
    end

    update :start do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :active})
    end

    update :pause do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :paused})
    end

    update :resume do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :active})
    end

    update :complete do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :completed})
    end

    update :archive do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :archived})
    end
  end
end
