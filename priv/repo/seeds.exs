require Ash.Query

alias Taskboard.Accounts.{User, Group, GroupMembership}
alias Taskboard.Templates.{Template, TemplateTask, TemplateTaskDependency}
alias Taskboard.Projects.{Context, Project}

IO.puts("==> Demo-Daten werden angelegt...")

# ---------------------------------------------------------------------------
# 1. Gruppen
# ---------------------------------------------------------------------------

eröffnungsteam =
  Ash.create!(Group, %{name: "Eröffnungsteam"}, authorize?: false)

bau =
  Ash.create!(Group, %{name: "Bau & Technik"}, authorize?: false)

marketing =
  Ash.create!(Group, %{name: "Marketing"}, authorize?: false)

IO.puts("   Gruppen: #{eröffnungsteam.name}, #{bau.name}, #{marketing.name}")

# ---------------------------------------------------------------------------
# 2. Demo-User
# ---------------------------------------------------------------------------

admin =
  case User
       |> Ash.Changeset.for_create(
         :register_with_password,
         %{
           email: "admin@demo.local",
           password: "Demo1234!",
           password_confirmation: "Demo1234!"
         },
         authorize?: false
       )
       |> Ash.create() do
    {:ok, user} ->
      IO.puts("   User angelegt: #{user.email}")
      user

    {:error, _} ->
      IO.puts("   User existiert bereits, lade...")
      email_val = "admin@demo.local"
      {:ok, existing} =
        User
        |> Ash.Query.filter(email == ^email_val)
        |> Ash.read_one(authorize?: false)
      existing
  end

Ash.create!(GroupMembership, %{user_id: admin.id, group_id: eröffnungsteam.id}, authorize?: false)
IO.puts("   #{admin.email} → #{eröffnungsteam.name}")

# ---------------------------------------------------------------------------
# 3. Template: Markt-Neueröffnung
# ---------------------------------------------------------------------------

template =
  Ash.create!(
    Template,
    %{
      name: "Markt-Neueröffnung",
      description: "Standardprozess für die Eröffnung eines neuen Marktes",
      family: "retail",
      reference_date_label: "Eröffnungsdatum",
      allowed_context_types: [:market]
    },
    authorize?: false
  )

IO.puts("   Template: #{template.name}")

# --- Kapitel 1: Bauvorbereitung ---
kap1 =
  Ash.create!(TemplateTask, %{title: "Bauvorbereitung", level: 0, position: 1,
    start_offset_days: -90, end_offset_days: -30,
    template_id: template.id, assigned_group_id: bau.id}, authorize?: false)

t1_1 =
  Ash.create!(TemplateTask, %{title: "Bauplan freigeben", level: 1, position: 1,
    start_offset_days: -90, end_offset_days: -75, warning_offset_days: 5,
    template_id: template.id, parent_id: kap1.id, assigned_group_id: bau.id}, authorize?: false)

t1_2 =
  Ash.create!(TemplateTask, %{title: "Baugenehmigung einholen", level: 1, position: 2,
    start_offset_days: -75, end_offset_days: -60, warning_offset_days: 7,
    template_id: template.id, parent_id: kap1.id, assigned_group_id: bau.id}, authorize?: false)

t1_3 =
  Ash.create!(TemplateTask, %{title: "Rohbau abschließen", level: 1, position: 3,
    start_offset_days: -60, end_offset_days: -30, warning_offset_days: 10,
    template_id: template.id, parent_id: kap1.id, assigned_group_id: bau.id}, authorize?: false)

# --- Kapitel 2: Einrichtung ---
kap2 =
  Ash.create!(TemplateTask, %{title: "Einrichtung & Ausstattung", level: 0, position: 2,
    start_offset_days: -30, end_offset_days: -7,
    template_id: template.id, assigned_group_id: eröffnungsteam.id}, authorize?: false)

t2_1 =
  Ash.create!(TemplateTask, %{title: "Regale und Möbel aufbauen", level: 1, position: 1,
    start_offset_days: -30, end_offset_days: -20, warning_offset_days: 3,
    template_id: template.id, parent_id: kap2.id, assigned_group_id: eröffnungsteam.id}, authorize?: false)

t2_2 =
  Ash.create!(TemplateTask, %{title: "Kassensysteme installieren", level: 1, position: 2,
    start_offset_days: -20, end_offset_days: -14, warning_offset_days: 3,
    template_id: template.id, parent_id: kap2.id, assigned_group_id: bau.id}, authorize?: false)

t2_3 =
  Ash.create!(TemplateTask, %{title: "Erstbefüllung Warenbestand", level: 1, position: 3,
    start_offset_days: -14, end_offset_days: -3, warning_offset_days: 2,
    template_id: template.id, parent_id: kap2.id, assigned_group_id: eröffnungsteam.id}, authorize?: false)

# --- Kapitel 3: Marketing ---
kap3 =
  Ash.create!(TemplateTask, %{title: "Marketing & Kommunikation", level: 0, position: 3,
    start_offset_days: -60, end_offset_days: 0,
    template_id: template.id, assigned_group_id: marketing.id}, authorize?: false)

t3_1 =
  Ash.create!(TemplateTask, %{title: "Eröffnungskampagne planen", level: 1, position: 1,
    start_offset_days: -60, end_offset_days: -30, warning_offset_days: 5,
    template_id: template.id, parent_id: kap3.id, assigned_group_id: marketing.id}, authorize?: false)

t3_2 =
  Ash.create!(TemplateTask, %{title: "Flyer & Werbemittel drucken", level: 1, position: 2,
    start_offset_days: -14, end_offset_days: -7, warning_offset_days: 3,
    template_id: template.id, parent_id: kap3.id, assigned_group_id: marketing.id}, authorize?: false)

t3_3 =
  Ash.create!(TemplateTask, %{title: "Eröffnungsevent koordinieren", level: 1, position: 3,
    start_offset_days: -7, end_offset_days: 0, warning_offset_days: 2,
    template_id: template.id, parent_id: kap3.id, assigned_group_id: marketing.id}, authorize?: false)

IO.puts("   TemplateTask-Kapitel: 3, Tasks: 9")

# --- Abhängigkeiten ---
deps = [
  {t1_1, t1_2},  # Bauplan → Baugenehmigung
  {t1_2, t1_3},  # Baugenehmigung → Rohbau
  {t1_3, t2_1},  # Rohbau → Regale
  {t2_1, t2_2},  # Regale → Kassen
  {t2_2, t2_3},  # Kassen → Warenbestand
  {t3_1, t3_2},  # Kampagne → Flyer
  {t3_2, t3_3}   # Flyer → Event
]

Enum.each(deps, fn {pred, succ} ->
  Ash.create!(TemplateTaskDependency,
    %{predecessor_id: pred.id, successor_id: succ.id, type: :finish_to_start, lag_days: 0},
    authorize?: false)
end)

IO.puts("   Abhängigkeiten: #{length(deps)}")

Ash.update!(template, %{}, action: :publish, authorize?: false)
IO.puts("   Template Status: active")

# ---------------------------------------------------------------------------
# 4. Kontext (Demo-Markt)
# ---------------------------------------------------------------------------

context =
  Ash.create!(Context, %{
    name: "Markt Hamburg-Nord",
    code: "HH-001",
    type: :market,
    external_id: "HH001",
    metadata: %{"adresse" => "Musterstraße 42, 20099 Hamburg", "region" => "Nord"}
  }, authorize?: false)

IO.puts("   Kontext: #{context.name}")

# ---------------------------------------------------------------------------
# 5. Projekt aktivieren (Eröffnung in 60 Tagen)
# ---------------------------------------------------------------------------

eröffnungsdatum = Date.add(Date.utc_today(), 60)

project =
  Project
  |> Ash.Changeset.for_create(:activate, %{
    template_id: template.id,
    context_id: context.id,
    reference_date: eröffnungsdatum,
    name: "Neueröffnung #{context.name}"
  }, authorize?: false)
  |> Ash.create!()

IO.puts("   Projekt: #{project.name} (Eröffnung: #{eröffnungsdatum})")

# ---------------------------------------------------------------------------
# 6. Ersten Task auf :done setzen, damit Abhängigkeitspropagierung sichtbar
# ---------------------------------------------------------------------------

require Ash.Query

{:ok, project_tasks} =
  Taskboard.Projects.ProjectTask
  |> Ash.Query.filter(project_id == ^project.id and level == 1)
  |> Ash.Query.sort(position: :asc)
  |> Ash.read(authorize?: false)

case Enum.find(project_tasks, &(&1.status == :open)) do
  nil -> :ok
  task ->
    Ash.update!(task, %{}, action: :complete, authorize?: false)
    IO.puts("   '#{task.title}' → done (Propagierung getriggert)")
end

IO.puts("")
IO.puts("==> Fertig!")
IO.puts("")
IO.puts("   Login:    admin@demo.local")
IO.puts("   Passwort: Demo1234!")
IO.puts("   URL:      http://localhost:4000")
