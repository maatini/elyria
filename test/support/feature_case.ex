defmodule TaskboardWeb.FeatureCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint TaskboardWeb.Endpoint

      use TaskboardWeb, :verified_routes

      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import TaskboardWeb.FeatureCase
    end
  end

  setup tags do
    Taskboard.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def create_user(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    defaults = %{
      email: "user#{n}@example.com",
      password: "Test1234!",
      password_confirmation: "Test1234!"
    }

    Taskboard.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, Map.merge(defaults, Map.new(attrs)),
      authorize?: false
    )
    |> Ash.create!()
  end

  def log_in_user(conn, user) do
    subject = AshAuthentication.user_to_subject(user)
    Phoenix.ConnTest.init_test_session(conn, %{"user" => subject})
  end
end
