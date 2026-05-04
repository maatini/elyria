defmodule Taskboard.Accounts do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Taskboard.Accounts.User)
    resource(Taskboard.Accounts.Token)
    resource(Taskboard.Accounts.Group)
    resource(Taskboard.Accounts.GroupMembership)
  end
end
