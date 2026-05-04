defmodule Taskboard.Accounts.Group do
  use Ash.Resource,
    domain: Taskboard.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "groups"
    repo Taskboard.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :color, :string, public?: true
    timestamps()
  end

  identities do
    identity :unique_name, [:name]
  end

  actions do
    defaults [:read, :destroy, create: [:name, :description, :color], update: [:name, :description, :color]]
  end

  relationships do
    has_many :group_memberships, Taskboard.Accounts.GroupMembership

    many_to_many :users, Taskboard.Accounts.User do
      through Taskboard.Accounts.GroupMembership
      source_attribute_on_join_resource :group_id
      destination_attribute_on_join_resource :user_id
    end
  end
end
