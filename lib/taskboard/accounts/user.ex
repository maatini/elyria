defmodule Taskboard.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    domain: Taskboard.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  authentication do
    tokens do
      enabled?(true)
      token_resource(Taskboard.Accounts.Token)
      signing_secret(Taskboard.Accounts.Secrets)
      require_token_presence_for_authentication?(false)
      session_identifier(:jti)
    end

    strategies do
      password :password do
        identity_field(:email)

        resettable do
          sender(Taskboard.Accounts.User.Senders.SendPasswordResetEmail)
        end
      end
    end
  end

  postgres do
    table("users")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:email, :ci_string, allow_nil?: false, public?: true)
    attribute(:hashed_password, :string, allow_nil?: true, sensitive?: true, public?: false)
    attribute(:name, :string, public?: true)

    attribute(:role, :atom,
      constraints: [one_of: [:user, :admin]],
      default: :user,
      public?: true
    )

    attribute(:confirmed_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  identities do
    identity(:unique_email, [:email])
  end

  actions do
    defaults([:read])

    read :by_email do
      argument(:email, :ci_string, allow_nil?: false)
      get?(true)
      filter(expr(email == ^arg(:email)))
    end

    update :confirm do
      accept([])
      change(set_attribute(:confirmed_at, &DateTime.utc_now/0))
    end
  end

  relationships do
    has_many :group_memberships, Taskboard.Accounts.GroupMembership

    many_to_many :groups, Taskboard.Accounts.Group do
      through(Taskboard.Accounts.GroupMembership)
      source_attribute_on_join_resource(:user_id)
      destination_attribute_on_join_resource(:group_id)
    end
  end
end
