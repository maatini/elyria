defmodule Taskboard.Projects do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Taskboard.Projects.Context)
    resource(Taskboard.Projects.ProjectType)
    resource(Taskboard.Projects.Project)
    resource(Taskboard.Projects.ProjectTask)
    resource(Taskboard.Projects.ProjectTaskDependency)
    resource(Taskboard.Projects.Milestone)
  end
end
