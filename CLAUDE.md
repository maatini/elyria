# CLAUDE.md – Taskboard Projekt

**Projektname:** `taskboard`  
**Zweck:** Produktionsreifes Projektmanagement-Tool für Marktoperationen (Neueöffnungen, Umstellungen, Betreiberwechsel) mit starkem Fokus auf Vorlagen, hierarchischen Aufgaben, Abhängigkeiten, Gantt-Visualisierung und persönlichen Dashboards.

**Version:** 2026-05-04 (optimiert für Claude 3.7 Sonnet / Artifacts / Projects)

---
## 0. Karpathy Core Guidelines (übernommen & angepasst)

### 0.1 Think Before Coding
- Nenne explizit Annahmen und Tradeoffs.
- Bei mehreren Interpretationen → liste sie auf und frage nach.
- Bei Unklarheiten sofort nachfragen, bevor Code geschrieben wird.
- Schlage einfachere Lösungen vor, wenn sie existieren.

### 0.2 Simplicity First
- Nur das implementieren, was explizit gefordert wurde.
- Keine spekulativen Abstraktionen oder „Zukunftssicherheit".
- Keine Abstraktionen für Einmal-Code.
- Wenn 200 Zeilen möglich sind, aber 50 reichen → schreibe die 50 und erkläre warum.
- Frage dich: Würde ein Senior Elixir-Entwickler das als over-engineered bezeichnen?

### 0.3 Surgical Changes
- Ändere **nur** das Notwendige.
- Keine Formatierungs- oder Stil-Verbesserungen in anderen Dateien.
- Passe dich exakt dem bestehenden Stil an.
- Entferne nur Code, der durch deine Änderung überflüssig geworden ist.
- Unrelated Dead Code: nur erwähnen, nicht löschen.

**Test:** Jede geänderte Zeile muss direkt auf die Anfrage des Users zurückführbar sein.

### 0.4 Goal-Driven Execution
- Definiere messbare Erfolgskriterien.
- Bei komplexen Aufgaben: Kurzen Plan + Verifizierungsschritte angeben.
- Warte auf Bestätigung des Users, bevor du zur nächsten Phase übergehst.

---

## 1. Technologie-Stack (exakt einhalten)

- **Backend:** Elixir 1.17+ / OTP 27+, Phoenix 1.7+ (LiveView 1.0+)
- **Framework:** Ash Framework 3.x (AshPostgres, AshPhoenix, AshOban, AshStateMachine, AshPolicies, AshPaperTrail, AshAuthentication)
- **Datenbank:** PostgreSQL 16+
- **Frontend:** Phoenix LiveView + Tailwind CSS + Heroicons + daisyUI (oder shadcn)
- **Gantt:** Frappe Gantt (open-source via npm/esbuild)
- **Jobs:** Oban
- **Dev-Umgebung:** Jetify Devbox (devbox.json)
- **Auth:** AshAuthentication (User + Sessions)

**Keine** separaten SPAs, keine React/Vue, keine zusätzlichen JS-Frameworks außer dem einen Frappe-Gantt-Hook.

---

## 2. Architektur-Prinzipien (immer befolgen)

- **Ash-first:** Jede Business-Entity ist eine Ash Resource. CRUD und Use-Cases werden als Actions, Calculations und Policies definiert.
- **Domains:**
  - `Template` (Vorlagen-Domain)
  - `Project` (Projekt-Domain)
  - `Account` (User, Group, GroupMembership)
- **Zwei-Ebenen-Hierarchie:** Nur `parent_id` + `level` + Materialized Path (`path`).
- **Alle schreibenden Operationen** in Transactions (`Ash.Changeset` + `Ecto.Multi` wo nötig).
- **Business-Regeln** deklarativ in Resources (Calculations, StateMachine, Policies).
- **Echtzeit:** LiveView + PubSub für alle Änderungen (Status, Gantt, My-Tasks).
- **Versionierung:** AshPaperTrail für Templates und Re-Aktivierung.
- **Separation:** Keine Logik im Controller/LiveView – alles delegiert an Ash Actions.

---

## 3. Domain-Modell (vollständig)

### Account-Domain
- `User` (human | technical)
- `Group`
- `GroupMembership` (Many-to-Many)

### Template-Domain
- `Template`
- `TemplateTask` (mit `assigned_group_id`)
- `Process`
- `TaskDependency` (TemplateTask → TemplateTask)

### Project-Domain
- `Project` (Status + Referenzdatum)
- `ProjectTask` (kopiert aus TemplateTask, mit absoluten Daten, `assigned_group_id`)
- `TaskDependency` (ProjectTask → ProjectTask)

**Wichtige Relationships:**
- `ProjectTask.belongs_to :assigned_group`
- `Group.has_many :users` via Membership
- `User.has_many :groups` via Membership

---

## 4. Kern-Funktionalitäten (Pflicht)

1. **Templates & Aktivierung**
   - Relative Zeitangaben → absolute Berechnung bei Aktivierung/Re-Aktivierung
   - Automatische Kapitelnummerierung
   - Hierarchie (max. 2 Ebenen)

2. **ProjectTasks**
   - Status-Propagierung (AshStateMachine)
   - Abhängigkeits-Blockierung
   - Group-Zuordnung (vererbt aus Template oder manuell änderbar)

3. **Persönliches Dashboard `/my-tasks`**
   - Zeigt **alle** anstehenden ProjectTasks, bei denen der aktuelle User in der `assigned_group` ist
   - Kriterien: Status `open` oder `in_progress`, sortiert nach Dringlichkeit (Warn-/Enddatum)
   - Filter, Suche, direkte Links zu Gantt und Task-Detail

4. **Gantt-Diagramm** (pro Project)
   - Frappe Gantt mit LiveView-Hook
   - Hover-Tooltip: Name, Kapitel, Group + Mitglieder, Status, Abhängigkeiten
   - Drag & Drop / Resize → Backend-Validierung
   - Abhängigkeits-Pfeile
   - Collapse/Expand Hierarchie
   - Echtzeit-Updates

5. **Benachrichtigungen**
   - Oban-Jobs (E-Mail + In-App)
   - Nur an User der zugeordneten Group

6. **Admin**
   - AshAdmin für alle Resources
   - User-/Group-Verwaltung (inkl. technische Nutzer)

### 4.1 Generalisierung / Multi-Domain-Fähigkeit
- Das System ist **nicht** auf Retail/Märkte beschränkt.
- Zentrales Resource `Context` (ehemals „Market“) mit `type` (:market, :plant, :project, :building, …).
- Templates sind pro Context-Type konfigurierbar.
- Flexible Custom Fields pro Template/ProjectType.
- Ziel: Einsetzbar in Retail, Produktion, IT, Facility Management, HR etc.

---

## 5. Entwicklungs-Regeln & Workflow

- **Iteratives Vorgehen:**
  1. Devbox + Initialisierung + AshAuthentication
  2. Account-Domain (User, Group, Membership)
  3. Template-Domain + Resources
  4. Project-Domain + Activation/Re-Activation
  5. My-Tasks Dashboard + Query
  6. Gantt LiveComponent + JS-Hook
  7. Views & Navigation
  8. Tests + README

- **Bei jeder Antwort:**
  - Nur geänderte/neue Dateien mit vollständigem Code anzeigen
  - Kurze Erklärung der Entscheidungen
  - Nächsten Schritt vorschlagen und auf Bestätigung warten

- **Code-Style:**
  - Elixir 1.17+ (Pattern Matching, Pipelines, `with`)
  - Ash DSL maximal deklarativ
  - Tailwind + daisyUI für sauberes, responsives UI
  - Ausführliche `@doc` und Typespecs wo sinnvoll

- **Devbox:**
  - Immer `devbox.json` zuerst aktualisieren
  - PostgreSQL, Node, Elixir, inotify-tools etc. enthalten

---

## 6. Nicht gewünscht

- Keine eigenen State-Machines außer AshStateMachine
- Keine GraphQL/JSON:API außer für interne Zwecke
- Keine zusätzlichen JS-Frameworks
- Keine direkten Ecto-Queries außerhalb von Ash (außer in ganz seltenen Escape-Hatches)

---

**Dies ist die Single Source of Truth.**  
Jede neue Session oder Fortsetzung beginnt mit: „Referenziere CLAUDE.md und fahre mit dem nächsten logischen Schritt fort.“

**Aktueller Status:** Projekt wird iterativ aufgebaut. Starte immer mit dem aktuell offenen Schritt.

---

**Ende der CLAUDE.md**