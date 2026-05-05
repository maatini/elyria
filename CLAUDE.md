# CLAUDE.md – Taskboard Projekt

**Projektname:** `taskboard`  
**Zweck:** Produktionsreifes Projektmanagement-Tool für Marktoperationen (Neueöffnungen, Umstellungen, Betreiberwechsel) mit starkem Fokus auf Vorlagen, hierarchischen Aufgaben, Abhängigkeiten, Gantt-Visualisierung und persönlichen Dashboards.

---

## 0. Projektspezifische Arbeitsregeln

- **Ash-first:** Keine Ecto-Queries direkt, keine Business-Logik in LiveViews — alles über Ash Actions.
- **Statusübergänge:** Immer über AshStateMachine-Transitions, nie `set_attribute(:status, ...)` direkt.
- **Migrations-Workflow:** Nach jeder Resource-Änderung `mix ash_postgres.generate_migrations --name <name>` ausführen, generierte Migration prüfen, dann `mix ecto.migrate`.
- **Vor jedem größeren Feature:** Kurzen Plan präsentieren und Bestätigung abwarten.
- **`authorize?: false`** nur in Change-Modulen und internen/kaskadierten Operationen.

---

## 1. Technologie-Stack (exakt einhalten)

- **Backend:** Elixir 1.18+ / OTP 27+, Phoenix 1.7+ (LiveView 1.0+)
- **Framework:** Ash Framework 3.x (AshPostgres, AshPhoenix, AshOban, AshStateMachine, AshPolicies, AshPaperTrail, AshAuthentication)
- **Datenbank:** PostgreSQL 16+
- **Frontend:** Phoenix LiveView + Tailwind CSS + Heroicons + daisyUI
- **Gantt:** Frappe Gantt (open-source via npm/esbuild)
- **Jobs:** Oban
- **Dev-Umgebung:** Jetify Devbox (devbox.json)
- **Auth:** AshAuthentication (User + Sessions)

**Nicht verwenden:** Keine SPAs, kein React/Vue, keine zusätzlichen JS-Frameworks außer dem Frappe-Gantt-Hook, keine direkten Ecto-Queries außerhalb von Ash.

---

## 2. Entwicklungsbefehle

```bash
mix phx.server                                          # Server starten
mix ash_postgres.generate_migrations --name <name>      # Migration generieren
mix ecto.migrate                                        # Migrationen ausführen
mix test                                                # Tests ausführen
mix format --check-formatted                            # Format prüfen
mix credo                                               # Code-Analyse
```

---

## 3. Architektur-Prinzipien

- **Ash-first:** Jede Business-Entity ist eine Ash Resource. CRUD und Use-Cases werden als Actions, Calculations und Policies definiert.
- **Domains:**
  - `Taskboard.Accounts` (User, Group, GroupMembership)
  - `Taskboard.Templates` (Vorlagen-Domain)
  - `Taskboard.Projects` (Projekt-Domain)
- **Drei-Ebenen-Hierarchie:** `parent_id` + `level` (0 = Kapitel, 1 = Task/Haupt-Task, 2 = Detail-Task).
- **Business-Regeln** deklarativ in Resources (Calculations, StateMachine, Changes, Policies).
- **Echtzeit:** LiveView + PubSub für alle Änderungen (Status, Gantt, My-Tasks).
- **Versionierung:** AshPaperTrail für Templates und Re-Aktivierung.
- **Separation:** Keine Logik im Controller/LiveView — alles delegiert an Ash Actions.

---

## 4. Domain-Modell

### Accounts-Domain
- `User` (human | technical)
- `Group`
- `GroupMembership` (Many-to-Many)

### Template-Domain
- `Template`
- `TemplateTask` — mit `task_type: :regular | :main | :detail`, `assigned_group_id`, `template_milestone_id`
- `TemplateTaskDependency` (TemplateTask → TemplateTask)
- `TemplateMilestone` — `due_offset_days`, `warning_offset_days`

### Project-Domain
- `Project` (Status + Referenzdatum)
- `ProjectTask` — kopiert aus TemplateTask, mit absoluten Daten, `task_type`, `assigned_group_id`, `milestone_id`
- `ProjectTaskDependency` (ProjectTask → ProjectTask)
- `Milestone` — `due_date`, `warning_date`, Calculations: `fulfilled?`, `overdue?`, `warning?`

**task_type-Semantik:**
- `:regular` — normaler Task (level 1), hat Daten, kann Meilenstein haben
- `:main` — Haupt-Task (level 1), bündelt Detail-Tasks; abgeschlossen wenn alle Details fertig
- `:detail` — Detail-Task (level 2), keine eigenen Daten, kein Meilenstein, kein Gantt-Eintrag

**Wichtige Relationships:**
- `ProjectTask.belongs_to :assigned_group`
- `ProjectTask.belongs_to :milestone` (nur `:regular` und `:main`)
- `ProjectTask.belongs_to :parent` (nur `:detail`)
- `Group.has_many :users` via GroupMembership

---

## 5. Kern-Funktionalitäten

1. **Templates & Aktivierung**
   - Relative Zeitangaben (`*_offset_days`) → absolute Berechnung bei Aktivierung
   - Automatische Kapitelnummerierung
   - Drei-Ebenen-Hierarchie (Kapitel → Haupt-Task → Detail-Task)

2. **ProjectTasks & Status-Maschine**
   - Zustände: `:open → :in_progress → :done`, `:blocked`, `:skipped`
   - `SyncMainTaskStatus`: Detail-Task-Änderung → Main-Task auto-starten oder auto-abschließen
   - `CascadeCompleteDetailTasks`: Main-Task explizit abschließen → alle Details werden abgeschlossen
   - `AutoReopenMainTask`: Detail-Task wiederöffnen → Main-Task wird wiedergeöffnet (falls done/skipped)
   - `PropagateStatusToSuccessors`: Status `:done`/`:skipped` → Nachfolger-Tasks entblocken

3. **Meilensteine**
   - `Milestone` pro Project, optional mit Tasks verknüpft (nur `:regular` und `:main`)
   - Erfüllt wenn alle verknüpften Tasks `:done` oder `:skipped`
   - Warnung und Überfälligkeits-Anzeige auf Dashboard

4. **Persönliches Dashboard `/my-tasks`**
   - Zeigt alle offenen/laufenden ProjectTasks der Gruppen des aktuellen Users
   - Sortiert nach Dringlichkeit (Warn-/Enddatum)

5. **Gantt-Diagramm** (pro Project)
   - Frappe Gantt mit LiveView-Hook
   - Detail-Tasks werden **nicht** im Gantt angezeigt
   - Drag & Drop / Resize → Backend-Validierung
   - Echtzeit-Updates via PubSub

6. **Benachrichtigungen**
   - Oban-Jobs (E-Mail + In-App)
   - Nur an User der zugeordneten Group

7. **Admin**
   - AshAdmin für alle Resources
   - User-/Group-Verwaltung (inkl. technische Nutzer)

---

## 6. Code-Style

- Ash DSL maximal deklarativ
- Elixir-Idiome: Pattern Matching, Pipelines, `with`
- `@doc` nur für public Actions/Calculations, wenn der Zweck nicht offensichtlich ist
- Keine Kommentare die erklären *was* der Code tut — nur *warum* (versteckte Constraints, Workarounds)

---

**Ende der CLAUDE.md**
