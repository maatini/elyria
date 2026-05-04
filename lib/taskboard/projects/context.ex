defmodule Taskboard.Projects.Context do
  use Ash.Resource,
    domain: Taskboard.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("contexts")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:code, :string, public?: true)

    attribute(:type, :atom,
      constraints: [
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
      ],
      allow_nil?: false,
      public?: true
    )

    # External reference (e.g. SAP ID, store number)
    attribute(:external_id, :string, public?: true)

    # Arbitrary metadata: address, region, manager, etc.
    attribute(:metadata, :map, default: %{}, public?: true)

    attribute(:active, :boolean, default: true, allow_nil?: false, public?: true)

    timestamps()
  end

  identities do
    identity(:unique_external_id_per_type, [:type, :external_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:name, :code, :type, :external_id, :metadata, :active])
    end

    update :update do
      accept([:name, :code, :metadata, :active])
      require_atomic?(false)
    end
  end

  relationships do
    has_many :projects, Taskboard.Projects.Project
  end
end
