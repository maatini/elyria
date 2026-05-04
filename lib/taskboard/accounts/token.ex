defmodule Taskboard.Accounts.Token do
  use Ash.Resource,
    domain: Taskboard.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(Taskboard.Repo)
  end
end
