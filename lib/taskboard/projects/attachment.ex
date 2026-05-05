defmodule Taskboard.Projects.Attachment do
  @moduledoc false
  use Ash.Resource,
    domain: Taskboard.Projects,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("attachments")
    repo(Taskboard.Repo)

    custom_statements do
      statement :exactly_one_parent do
        up("""
        ALTER TABLE attachments
          ADD CONSTRAINT exactly_one_parent CHECK (
            (project_id IS NOT NULL)::int + (project_task_id IS NOT NULL)::int = 1
          )
        """)

        down("ALTER TABLE attachments DROP CONSTRAINT IF EXISTS exactly_one_parent")
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:filename, :string, allow_nil?: false, public?: true)
    attribute(:content_type, :string, allow_nil?: false, public?: true)
    attribute(:size_bytes, :integer, allow_nil?: false, public?: true)
    attribute(:storage_path, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :project, Taskboard.Projects.Project, allow_nil?: true, public?: true
    belongs_to :project_task, Taskboard.Projects.ProjectTask, allow_nil?: true, public?: true
    belongs_to :uploaded_by, Taskboard.Accounts.User, allow_nil?: false, public?: true
  end

  validations do
    validate(fn changeset, _ctx ->
      project_id = Ash.Changeset.get_attribute(changeset, :project_id)
      project_task_id = Ash.Changeset.get_attribute(changeset, :project_task_id)

      case {is_nil(project_id), is_nil(project_task_id)} do
        {true, true} ->
          {:error,
           field: :base, message: "Entweder project_id oder project_task_id muss gesetzt sein"}

        {false, false} ->
          {:error,
           field: :base, message: "Nur eine von project_id oder project_task_id darf gesetzt sein"}

        _ ->
          :ok
      end
    end)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :filename,
        :content_type,
        :size_bytes,
        :storage_path,
        :description,
        :project_id,
        :project_task_id,
        :uploaded_by_id
      ])
    end

    update :update do
      accept([:description])
      require_atomic?(false)
    end
  end
end
