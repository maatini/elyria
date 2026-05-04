defmodule Taskboard.Templates.Template do
  @moduledoc false
  use Ash.Resource,
    domain: Taskboard.Templates,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine]

  state_machine do
    state_attribute(:status)
    initial_states([:draft])
    default_initial_state(:draft)

    transitions do
      transition(:publish, from: :draft, to: :active)
      transition(:archive, from: [:draft, :active], to: :archived)
      transition(:restore, from: :archived, to: :draft)
    end
  end

  postgres do
    table("templates")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)

    attribute(:family, :string, public?: true)
    attribute(:reference_date_label, :string, default: "Referenzdatum", public?: true)

    attribute(:allowed_context_types, {:array, :atom},
      constraints: [
        items: [
          one_of: [
            :market,
            :plant,
            :building,
            :customer_project,
            :department,
            :it_project,
            :hr_project,
            :facility,
            :generic
          ]
        ]
      ],
      default: [:generic],
      public?: true
    )

    timestamps()
  end

  identities do
    identity(:unique_name_per_family, [:name, :family])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :description, :family, :reference_date_label, :allowed_context_types])
    end

    update :update do
      accept([:name, :description, :family, :reference_date_label, :allowed_context_types])
      require_atomic?(false)
    end

    # AshStateMachine transition actions (state change is added by the extension)
    update :publish do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :active})
    end

    update :archive do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :archived})
    end

    update :restore do
      accept([])
      require_atomic?(false)
      change({AshStateMachine.BuiltinChanges.TransitionState, target: :draft})
    end
  end

  relationships do
    has_many :tasks, Taskboard.Templates.TemplateTask
    has_many :custom_field_definitions, Taskboard.Templates.CustomFieldDefinition
  end
end
