defmodule Taskboard.Projects.ProjectType do
  use Ash.Resource,
    domain: Taskboard.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "project_types"
    repo Taskboard.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true

    attribute :allowed_context_types, {:array, :atom},
      default: [:generic],
      public?: true

    timestamps()
  end

  identities do
    identity :unique_name, [:name]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :allowed_context_types]
    end

    update :update do
      accept [:name, :description, :allowed_context_types]
      require_atomic? false
    end
  end

  relationships do
    has_many :projects, Taskboard.Projects.Project
  end
end
