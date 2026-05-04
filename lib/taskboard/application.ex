defmodule Taskboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TaskboardWeb.Telemetry,
      Taskboard.Repo,
      {DNSCluster, query: Application.get_env(:taskboard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Taskboard.PubSub},
      {Oban, Application.fetch_env!(:taskboard, Oban)},
      {AshAuthentication.Supervisor, otp_app: :taskboard},
      TaskboardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Taskboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TaskboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
