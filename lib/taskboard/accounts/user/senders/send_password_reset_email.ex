defmodule Taskboard.Accounts.User.Senders.SendPasswordResetEmail do
  use AshAuthentication.Sender
  require Logger

  @impl AshAuthentication.Sender
  def send(_user, token, _opts) do
    Logger.warning("Password reset token (dev only): #{token}")
    :ok
  end
end
