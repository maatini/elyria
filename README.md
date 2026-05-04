# Taskboard

[![CI](https://github.com/maatini/elyria/actions/workflows/ci.yml/badge.svg)](https://github.com/maatini/elyria/actions/workflows/ci.yml)
[![Elixir](https://img.shields.io/badge/Elixir-1.18-4e2a8e?logo=elixir&logoColor=white)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/OTP-27-red?logo=erlang&logoColor=white)](https://www.erlang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-fd4f00?logo=phoenixframework&logoColor=white)](https://phoenixframework.org)
[![Ash Framework](https://img.shields.io/badge/Ash-3.x-f97316)](https://ash-hq.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169e1?logo=postgresql&logoColor=white)](https://www.postgresql.org)

![Taskboard Screenshot](docs/taskboard.png)

Generisches Projektausführungssystem für beliebige Branchen (Retail, IT, HR, Facility Management, Produktion). Projekte werden aus konfigurierbaren Vorlagen aktiviert, Aufgaben über ein persönliches Dashboard verwaltet und der Fortschritt per Gantt-Diagramm und Meilenstein-Übersicht visualisiert. Die Plattform ist branchenunabhängig – dasselbe System bedient Marktneueröffnungen ebenso wie IT-Rollouts oder HR-Onboardings.

---

## Inhalt

- [Stack](#stack)
- [Architektur](#architektur)
- [Datenmodell](#datenmodell)
- [Kern-Features](#kern-features)
- [Setup](#setup)
- [Entwicklung](#entwicklung)
- [Tests](#tests)
- [CI/CD](#cicd)
- [Wichtige URLs](#wichtige-urls)

---

## Stack

| Schicht | Technologie |
|---------|-------------|
| Sprache / Runtime | Elixir 1.18 / OTP 27 |
| Web-Framework | Phoenix 1.8.5 + LiveView 1.0 |
| Business-Layer | Ash Framework 3.x (AshPostgres, AshStateMachine, AshAuthentication, AshPhoenix, AshAdmin, AshOban, AshPaperTrail) |
| Datenbank | PostgreSQL 16 |
| Frontend | Tailwind CSS 4 + daisyUI 5 + Heroicons 2 |
| Gantt | Frappe Gantt (LiveView-Hook, kein separates SPA) |
| Hintergrundjobs | Oban 2 via AshOban |
| Authentifizierung | AshAuthentication 4 (JWT, `session_identifier: :jti`, kein DB-Token-Lookup) |
| Dev-Umgebung | Jetify Devbox (Elixir, PostgreSQL, Node.js 22 isoliert) |
| Linting / Typen | Credo 1.7 (strict) + Dialyxir 1.4 |

**Kein** separates SPA, kein React/Vue, keine GraphQL-API nach außen.

---

## Architektur

Die Anwendung folgt dem **Ash-first**-Prinzip: Jede Business-Entität ist eine Ash Resource. Lese- und Schreiboperationen sind ausschließlich über Ash Actions, Calculations und Policies definiert. LiveViews delegieren Logik vollständig an den Ash-Layer und enthalten selbst kein Business-Wissen.

### Domains

```
Taskboard
├── Accounts        User, Group, GroupMembership
├── Templates       Template, TemplateTask, TemplateTaskDependency, TemplateMilestone,
│                   CustomFieldDefinition
└── Projects        Context, ProjectType, Project, ProjectTask, ProjectTaskDependency,
                    Milestone
```

### Aufgaben-Hierarchie und Typen

Aufgaben haben ein `level`-Feld (0 = Kapitel, 1 = Aufgabe) und ein `parent_id`. Kapitelnummern werden als Ash Calculation berechnet (`ChapterNumber`) und erfordern kein gespeichertes Feld.

Zusätzlich unterscheidet das `task_type`-Attribut drei Varianten:

| Typ | Bedeutung |
|-----|-----------|
| `:regular` | Normale Aufgabe (Standard) |
| `:main` | Haupt-Aufgabe mit untergeordneten Detail-Tasks; wird automatisch abgeschlossen, wenn alle Details terminal sind |
| `:detail` | Detail-Task eines Main-Tasks; kann keinem Meilenstein direkt zugeordnet werden |

### Echtzeit

LiveView + Phoenix PubSub sorgen dafür, dass Statusänderungen, Gantt-Updates und Dashboard-Werte ohne Seitenreload propagiert werden.

---

## Datenmodell

### Account-Domain

| Resource | Felder / Besonderheiten |
|----------|------------------------|
| `User` | E-Mail + Passwort-Hash, Rolle (human / technical), AshAuthentication JWT |
| `Group` | Name, Beschreibung – repräsentiert Abteilungen, Teams oder Rollen |
| `GroupMembership` | Verbindet User ↔ Group mit einer optionalen Rolle (member / lead) |

### Template-Domain

| Resource | Felder / Besonderheiten |
|----------|------------------------|
| `Template` | Name, Status (draft → active → archived), AshPaperTrail-Versionierung |
| `TemplateTask` | Titel, level (0/1), position, relative Datumsoffsets (`start_offset_days`, `end_offset_days`, `warning_offset_days`), `assigned_group_id` |
| `TemplateTaskDependency` | predecessor → successor (Finish-to-Start) |
| `TemplateMilestone` | Name, `due_offset_days`, `warning_offset_days` – Vorlage für Projektmeilensteine |
| `CustomFieldDefinition` | Benutzerdefinierte Felder (Typ, Pflichtfeld, Optionen) pro Template |

### Project-Domain

| Resource | Felder / Besonderheiten |
|----------|------------------------|
| `Context` | Ausführungskontext: Markt, Werk, IT-System, Gebäude … Typ-Feld für Multi-Domain-Fähigkeit |
| `ProjectType` | Kategorisierung von Projekten |
| `Project` | Name, `reference_date`, Status (draft → active → paused / completed / archived), Verknüpfung zu Template und Context |
| `ProjectTask` | Kopie einer TemplateTask mit absoluten Daten, `task_type` (regular / main / detail), Status-State-Machine, `warning_date`, `completed_at`, `milestone_id`, Custom Field Values |
| `ProjectTaskDependency` | predecessor → successor analog zu Template |
| `Milestone` | Name, `due_date`, `warning_date`; Calculations: `fulfilled?`, `overdue?`, `warning?`; hat viele Tasks |

---

## Kern-Features

### 1. Vorlagen & Aktivierung

Templates bestehen aus hierarchischen Aufgaben und Meilensteinen mit relativen Zeitoffsets. Beim Anlegen eines Projekts (`Project.create :activate`) werden alle `TemplateTask`-Einträge in `ProjectTask`-Einträge kopiert. Relative Offsets werden relativ zum `reference_date` in absolute Daten umgerechnet. Aufgaben mit eingehenden Abhängigkeiten starten im Status `:blocked`, alle anderen als `:open`.

### 2. Status-State-Machine (AshStateMachine)

```
ProjectTask:
  :blocked ──unblock──► :open ──start──► :in_progress ──complete──► :done
                         │                    │
                         └────────skip────────┴───────────────────► :skipped
                         :done / :skipped ──reopen──────────────► :open

Project:
  :draft ──activate──► :active ──pause──► :paused ──resume──► :active
                          └────complete / archive────────────► :completed / :archived
```

### 3. Automatische Abhängigkeits- und Status-Propagierung

Drei Change-Module sorgen für automatische Statusübergänge:

| Modul | Auslöser | Effekt |
|-------|----------|--------|
| `PropagateStatusToSuccessors` | Task wird `done` / `skipped` | Blockierte Folgetasks werden entsperrt, sobald alle Vorgänger terminal sind |
| `SyncMainTaskStatus` | Detail-Task ändert Status | Haupt-Task startet automatisch (wenn Detail in Arbeit) bzw. schließt ab (wenn alle Details terminal) |
| `CascadeCompleteDetailTasks` | Main-Task wird `complete` | Alle untergeordneten Detail-Tasks werden ebenfalls abgeschlossen |
| `AutoReopenMainTask` | Detail-Task wird `reopen` | Haupt-Task wird wiedereröffnet, falls er bereits `done`/`skipped` war |

### 4. Meilensteine (`/projects/:id/milestones`)

Projekte können Meilensteine mit Fälligkeits- und Warndatum haben. Tasks werden Meilensteinen zugeordnet (`assign_milestone`-Action). Die Meilenstein-Ansicht zeigt Fortschrittsbalken (erledigte Tasks vs. Gesamt) und farbliche Statusmarkierungen:

- **Grün** – `fulfilled?`: alle zugeordneten Tasks terminal
- **Rot** – `overdue?`: `due_date` überschritten
- **Gelb** – `warning?`: `warning_date` erreicht

### 5. Meine Aufgaben (`/my-tasks`)

Zeigt alle `ProjectTask`-Einträge mit Status `:open` oder `:in_progress`, bei denen der eingeloggte User Mitglied der zugeordneten Gruppe ist. Sortierung nach Dringlichkeit (überfällige zuerst, dann nach Enddatum). Farbliche Markierung:

- **Rot** – `overdue?`: `end_date` liegt in der Vergangenheit
- **Gelb** – `warning?`: `warning_date` ist erreicht, `end_date` aber noch nicht

### 6. Dashboard & Kritische-Aufgaben-Dialog

Das Dashboard zeigt Kennzahlen (offene Tasks, überfällige Tasks, aktive Projekte, aktive Vorlagen). Beim Laden öffnet sich automatisch ein daisyUI-Dialog, wenn kritische Aufgaben (overdue oder warning) in den eigenen Gruppen vorhanden sind. Der Dialog listet diese Aufgaben mit Projekt, Gruppe und Enddatum auf. Der Überfällig-Zähler im Dashboard öffnet den Dialog erneut.

### 7. Gantt-Diagramm (`/projects/:id/gantt`)

Frappe Gantt ist als LiveView-Hook eingebunden. Jeder Task erhält eine `custom_class` basierend auf seinem Status (`gantt-open`, `gantt-in_progress`, `gantt-done`, `gantt-skipped`, `gantt-warning`, `gantt-overdue`), die farbliche Balken-Hervorhebung steuert. Das Popup zeigt Titel, Kapitelnummer und Gruppen-Zuordnung über die frappe-gantt 1.x Controller-API (`set_title` / `set_subtitle`). Drag & Drop und Resize schreiben Daten direkt zurück.

### 8. Admin (`/admin`)

AshAdmin bietet vollständige CRUD-Oberflächen für alle Resources. Hier werden Vorlagen, Aufgaben, Gruppen, Kontexte, Meilensteine und Projekte verwaltet.

### 9. Hintergrundjobs (Oban + AshOban)

Oban-Jobs versenden Benachrichtigungen (E-Mail + In-App) an die Mitglieder der zugeordneten Gruppe, wenn Warn- oder Enddaten erreicht werden.

---

## Setup

### Voraussetzungen

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16
- Node.js 22+

### Mit Devbox (empfohlen)

Devbox isoliert Elixir, PostgreSQL und Node.js lokal ohne systemweite Installation.

```bash
# Devbox installieren: https://www.jetify.com/devbox
devbox shell

# Einmalig: PostgreSQL initialisieren, Abhängigkeiten und Datenbank einrichten
devbox run setup

# Entwicklungsserver starten (startet PostgreSQL automatisch)
devbox run server
```

Weitere Devbox-Skripte:

```bash
devbox run db:start    # PostgreSQL starten
devbox run db:stop     # PostgreSQL stoppen
devbox run db:status   # PostgreSQL-Status
devbox run reset       # Datenbank zurücksetzen (drop + migrate + seeds)
```

### Ohne Devbox

```bash
# PostgreSQL muss extern laufen (config/dev.exs anpassen)
mix setup         # deps.get + ash.codegen + ecto.create + ash.migrate + seeds
mix phx.server    # http://localhost:4000
```

### Demo-Daten

`mix setup` führt `priv/repo/seeds.exs` aus und legt folgende Demo-Daten an:

| Was | Wert |
|-----|------|
| Demo-User | `admin@demo.local` / `Demo1234!` |
| Gruppen | Projektleitung, IT-Infrastruktur, Facility |
| Vorlage | „Neueröffnung Standard" (3 Kapitel, 9 Aufgaben, 7 Abhängigkeiten) |
| Kontext | Demo-Markt |
| Projekt | Aktiviert auf `reference_date = heute + 60 Tage` |

---

## Entwicklung

```bash
# Interaktive Shell mit laufender Applikation
iex -S mix phx.server

# Neue Ash-Migration generieren (nach Änderungen an Resources)
mix ash.codegen <migration_name>
mix ash.migrate

# Code-Qualität (lokal)
mix format
mix credo --strict
mix dialyzer         # Beim ersten Aufruf mehrere Minuten (PLT-Aufbau)

# Pre-Commit-Check (compile + format + test)
mix precommit
```

### Projektstruktur

```
lib/
├── taskboard/
│   ├── accounts/              # User, Group, GroupMembership, Token, Secrets
│   ├── projects/
│   │   ├── context.ex
│   │   ├── milestone.ex                             # Projektmeilenstein + Calculations
│   │   ├── project.ex
│   │   ├── project_task.ex                          # task_type, milestone_id, State-Machine
│   │   ├── project_task_dependency.ex
│   │   ├── project_type.ex
│   │   ├── project/changes/activate.ex              # Template → Projekt-Kopie
│   │   └── project_task/
│   │       ├── calculations/chapter_number.ex       # „1.2" aus level + position
│   │       ├── calculations/overdue.ex              # end_date < today
│   │       ├── calculations/warning.ex              # warning_date < today
│   │       ├── changes/auto_reopen_main_task.ex     # Detail reopen → Main reopen
│   │       ├── changes/cascade_complete_detail_tasks.ex  # Main complete → Details complete
│   │       ├── changes/propagate_status_to_successors.ex # Abhängigkeitskette auflösen
│   │       └── changes/sync_main_task_status.ex    # Detail-Status → Main-Status sync
│   └── templates/
│       ├── template.ex
│       ├── template_milestone.ex                    # Meilenstein-Vorlage mit Offsets
│       ├── template_task.ex
│       ├── template_task_dependency.ex
│       ├── custom_field_definition.ex
│       └── template_task/calculations/chapter_number.ex
└── taskboard_web/
    ├── live/
    │   ├── dashboard_live.ex        # Kennzahlen + Kritische-Aufgaben-Dialog
    │   ├── my_tasks_live.ex         # Persönliche Aufgabenübersicht
    │   ├── project_gantt_live.ex    # Gantt-Diagramm (Frappe Gantt Hook)
    │   ├── project_milestones_live.ex  # Meilenstein-Verwaltung pro Projekt
    │   ├── projects_live.ex         # Projektliste
    │   └── templates_live.ex        # Vorlagenliste
    └── components/
        └── layouts.ex               # App-Layout mit Navbar + Auth-Status

assets/
├── js/gantt_hook.js                 # Frappe Gantt LiveView-Hook (v1.x API)
├── css/app.css                      # Tailwind + daisyUI + Gantt-Statusfarben
└── vendor/                          # frappe-gantt.js, daisyUI, Heroicons
```

---

## Tests

```bash
mix test
```

```
test/
├── support/
│   ├── conn_case.ex          # ConnCase für Controller-Tests
│   ├── data_case.ex          # DB-Sandbox (Ecto.Adapters.SQL.Sandbox)
│   └── factory.ex            # Test-Datenfabrik
└── taskboard/
    ├── calculations_test.exs         # Unit-Tests: ChapterNumber, Overdue, Warning
    └── projects/
        ├── activation_test.exs       # Integrations-Test: Vorlage → Projekt
        └── propagation_test.exs      # Integrations-Test: Status-Propagierung
```

---

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`) mit 6 parallelen Jobs:

| Job | `MIX_ENV` | Befehl | Beschreibung |
|-----|-----------|--------|-------------|
| `format` | `test` | `mix format --check-formatted` | Einheitliche Code-Formatierung |
| `compile` | `test` | `mix compile --warnings-as-errors` | Keine Compiler-Warnungen erlaubt |
| `test` | `test` | `mix test` | Integrationstests gegen PostgreSQL 16 |
| `security` | `test` | `mix hex.audit` | Bekannte Schwachstellen in Dependencies |
| `credo` | `test` | `mix credo --strict` | Statische Code-Analyse (Style, Komplexität) |
| `dialyzer` | `dev` | `mix dialyzer` | Typprüfung; läuft mit `MIX_ENV=dev` damit ExUnit-Internals nicht analysiert werden |

Dependencies werden per `actions/cache` mit dem `mix.lock`-Hash als Schlüssel gecacht. Der Dialyzer-PLT hat einen eigenen Cache-Key (`plt-...`), der nur bei Dependency-Änderungen invalidiert wird.

---

## Wichtige URLs

| URL | Beschreibung |
|-----|-------------|
| `/` | Weiterleitung zu Dashboard (eingeloggt) oder Sign-In |
| `/sign-in` | Anmeldung |
| `/sign-up` | Registrierung |
| `/dashboard` | Kennzahlen, Schnellzugriff, kritische Aufgaben |
| `/my-tasks` | Persönliche Aufgabenübersicht (alle eigenen Gruppen) |
| `/projects` | Projektliste |
| `/projects/:id/gantt` | Gantt-Diagramm für ein Projekt |
| `/projects/:id/milestones` | Meilenstein-Verwaltung für ein Projekt |
| `/templates` | Vorlagenliste |
| `/admin` | AshAdmin (vollständige CRUD-Oberfläche) |
| `/dev/dashboard` | Phoenix LiveDashboard (nur dev) |
| `/dev/mailbox` | Swoosh Mailbox Preview (nur dev) |
