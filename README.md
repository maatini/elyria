# Taskboard

Ein generisches Projektausführungssystem für beliebige Branchen (Retail, IT, HR, Facility, Produktion). Projekte werden aus konfigurierbaren Vorlagen aktiviert und über Gantt-Diagramme sowie ein persönliches Aufgaben-Dashboard verwaltet.

## Stack

- **Elixir / OTP** + **Phoenix LiveView** (Echtzeit, kein SPA)
- **Ash Framework 3.x** (AshPostgres, AshStateMachine, AshAuthentication, AshAdmin)
- **PostgreSQL 16**
- **Tailwind CSS 4** + **daisyUI 5** + **Frappe Gantt**
- **Oban** für Hintergrundjobs

## Voraussetzungen

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16
- Node.js 20+ (für Asset-Build)

### Mit Devbox (empfohlen)

```bash
devbox shell
devbox run setup
```

### Ohne Devbox

```bash
# PostgreSQL muss lokal laufen
mix setup
```

## Setup

```bash
# Abhängigkeiten, Datenbank, Migrationen, Assets
mix setup

# Entwicklungsserver starten
mix phx.server
# oder interaktiv:
iex -S mix phx.server
```

Die Anwendung ist unter [http://localhost:4000](http://localhost:4000) erreichbar.

## Wichtige URLs

| URL | Beschreibung |
|-----|-------------|
| `/` | Startseite |
| `/sign-in` | Anmeldung |
| `/dashboard` | Übersicht & Schnellzugriff |
| `/my-tasks` | Meine Aufgaben (alle offenen Tasks der eigenen Gruppen) |
| `/projects` | Projektliste |
| `/projects/:id/gantt` | Gantt-Diagramm für ein Projekt |
| `/templates` | Vorlagenliste |
| `/admin` | AshAdmin (vollständige CRUD-Oberfläche) |

## Datenmodell

### Account-Domain
- `User` – Benutzer mit E-Mail + Passwort (AshAuthentication)
- `Group` – Gruppe (Abteilung, Team)
- `GroupMembership` – Zuordnung User ↔ Gruppe mit Rolle (member/lead)

### Template-Domain
- `Template` – Vorlage (Status: draft → active → archived)
- `TemplateTask` – Aufgabe/Kapitel in einer Vorlage (level 0 = Kapitel, level 1 = Aufgabe)
- `TemplateTaskDependency` – Abhängigkeit zwischen Template-Aufgaben
- `CustomFieldDefinition` – Benutzerdefinierte Felder pro Vorlage

### Project-Domain
- `Context` – Ausführungskontext (Markt, IT-Projekt, Abteilung …)
- `ProjectType` – Projekttyp
- `Project` – Konkretes Projekt, aktiviert aus einer Vorlage (Status: draft → active → paused/completed/archived)
- `ProjectTask` – Aufgabe im Projekt mit absoluten Daten (Status: open → in_progress → done/skipped)
- `ProjectTaskDependency` – Abhängigkeit zwischen Projekt-Aufgaben

## Kern-Features

### Vorlagen-Aktivierung
Beim Aktivieren eines Projekts (`Project.create :activate`) werden alle `TemplateTask`-Einträge in `ProjectTask`-Einträge kopiert. Relative Datumsoffsets (z.B. `start_offset_days: 5`) werden relativ zum `reference_date` des Projekts in absolute Daten umgerechnet.

Tasks mit eingehenden Abhängigkeiten starten im Status `:blocked`, alle anderen als `:open`.

### Status-Propagierung
Wird eine Aufgabe auf `:done` oder `:skipped` gesetzt, prüft `PropagateStatusToSuccessors`, ob alle Vorgänger einer blockierten Folgeaufgabe ebenfalls terminal sind. Wenn ja, wird die Folgeaufgabe automatisch auf `:open` gesetzt (`unblock`-Transition).

### Gantt-Diagramm
Das Gantt-Diagramm unter `/projects/:id/gantt` nutzt [Frappe Gantt](https://frappe.io/gantt) als LiveView-Hook. Drag & Drop sowie Resize-Operationen schreiben Daten direkt in die Datenbank zurück.

### Meine Aufgaben
`/my-tasks` zeigt alle offenen/in-Arbeit-Aufgaben bei denen der eingeloggte User Mitglied der zugeordneten Gruppe ist. Sortierung nach Enddatum, Farb-Markierung für überfällige (rot) und Warn-Aufgaben (gelb).

## Tests

```bash
mix test
```

Teststruktur:

```
test/
├── support/
│   ├── data_case.ex        # DB-Sandbox für Integrationstests
│   └── factory.ex          # Test-Datenfabrik
├── taskboard/
│   ├── calculations_test.exs           # Unit-Tests für Berechnungen
│   └── projects/
│       ├── activation_test.exs         # Integrationstests: Aktivierung
│       └── propagation_test.exs        # Integrationstests: Status-Propagierung
└── taskboard_web/
    └── controllers/                    # Controller-Tests
```

## Migrationen

```bash
# Neue Migration aus Ash-Resourcen generieren
mix ash.codegen <name>

# Migrationen ausführen
mix ash.migrate
```

## Admin

AshAdmin ist unter `/admin` erreichbar und bietet vollständige CRUD-Oberflächen für alle Resourcen. Hier können Vorlagen, Aufgaben, Gruppen und Projekte verwaltet werden.
