defmodule Taskboard.Templates do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Taskboard.Templates.Template)
    resource(Taskboard.Templates.TemplateTask)
    resource(Taskboard.Templates.TemplateTaskDependency)
    resource(Taskboard.Templates.CustomFieldDefinition)
    resource(Taskboard.Templates.TemplateMilestone)
  end
end
