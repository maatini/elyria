defmodule Taskboard.Templates.CustomFieldDefinition do
  @moduledoc false
  use Ash.Resource,
    domain: Taskboard.Templates,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("custom_field_definitions")
    repo(Taskboard.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Machine name used as key in custom_field_defaults/values maps
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:label, :string, allow_nil?: false, public?: true)

    attribute(:field_type, :atom,
      constraints: [one_of: [:text, :number, :select, :date, :boolean, :file, :gps]],
      default: :text,
      public?: true
    )

    attribute(:required, :boolean, default: false, public?: true)
    attribute(:position, :integer, default: 1, public?: true)

    # Flexible config: select options list, number min/max, text max_length, etc.
    attribute(:options, :map, default: %{}, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :template, Taskboard.Templates.Template, allow_nil?: false
  end

  identities do
    identity(:unique_name_per_template, [:template_id, :name])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :label, :field_type, :required, :position, :options, :template_id])
    end

    update :update do
      accept([:label, :field_type, :required, :position, :options])
      require_atomic?(false)
    end
  end
end
