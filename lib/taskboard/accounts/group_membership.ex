defmodule Taskboard.Accounts.GroupMembership do
  use Ash.Resource,
    domain: Taskboard.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "group_memberships"
    repo Taskboard.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom,
      constraints: [one_of: [:member, :lead]],
      default: :member,
      public?: true

    timestamps()
  end

  relationships do
    belongs_to :group, Taskboard.Accounts.Group, allow_nil?: false
    belongs_to :user, Taskboard.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_membership, [:group_id, :user_id]
  end

  actions do
    defaults [:read, :destroy, create: [:group_id, :user_id, :role], update: [:role]]
  end
end
