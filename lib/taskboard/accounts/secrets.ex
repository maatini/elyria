defmodule Taskboard.Accounts.Secrets do
  @moduledoc false
  use AshAuthentication.Secret

  @impl AshAuthentication.Secret
  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Taskboard.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:taskboard, :token_signing_secret)
  end
end
