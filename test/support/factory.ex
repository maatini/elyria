defmodule Taskboard.Factory do
  @moduledoc "Test data factory for Ash resources."

  def create_template(attrs \\ %{}) do
    Ash.create!(
      Taskboard.Templates.Template,
      Map.merge(%{name: "Test Template"}, Map.new(attrs)),
      authorize?: false
    )
  end

  def create_chapter(template, attrs \\ %{}) do
    Ash.create!(
      Taskboard.Templates.TemplateTask,
      Map.merge(
        %{template_id: template.id, title: "Kapitel", level: 0, position: 1},
        Map.new(attrs)
      ),
      authorize?: false
    )
  end

  def create_task(template, parent, attrs \\ %{}) do
    Ash.create!(
      Taskboard.Templates.TemplateTask,
      Map.merge(
        %{
          template_id: template.id,
          parent_id: parent.id,
          title: "Aufgabe",
          level: 1,
          position: 1,
          start_offset_days: 0,
          end_offset_days: 7
        },
        Map.new(attrs)
      ),
      authorize?: false
    )
  end

  def create_task_dep(predecessor, successor, attrs \\ %{}) do
    Ash.create!(
      Taskboard.Templates.TemplateTaskDependency,
      Map.merge(%{predecessor_id: predecessor.id, successor_id: successor.id}, Map.new(attrs)),
      authorize?: false
    )
  end

  def create_context(attrs \\ %{}) do
    Ash.create!(
      Taskboard.Projects.Context,
      Map.merge(%{name: "Test Context", type: :generic}, Map.new(attrs)),
      authorize?: false
    )
  end

  def create_group(attrs \\ %{}) do
    Ash.create!(
      Taskboard.Accounts.Group,
      Map.merge(%{name: "Test Group"}, Map.new(attrs)),
      authorize?: false
    )
  end

  def create_membership(group, user, attrs \\ %{}) do
    Ash.create!(
      Taskboard.Accounts.GroupMembership,
      Map.merge(%{group_id: group.id, user_id: user.id}, Map.new(attrs)),
      authorize?: false
    )
  end

  def activate_project(template, context, opts \\ %{}) do
    Taskboard.Projects.Project
    |> Ash.Changeset.for_create(
      :activate,
      Map.merge(
        %{
          template_id: template.id,
          context_id: context.id,
          reference_date: ~D[2026-06-01]
        },
        Map.new(opts)
      ),
      authorize?: false
    )
    |> Ash.create!()
  end
end
