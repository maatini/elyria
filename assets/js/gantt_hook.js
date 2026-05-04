import Gantt from "frappe-gantt"

const VIEW_MODES = ["Quarter Day", "Half Day", "Day", "Week", "Month", "Quarter Year", "Year"]

const GanttHook = {
  mounted() {
    this.gantt = null
    this.viewMode = this.el.dataset.viewMode || "Week"
    this.initGantt()

    this.handleEvent("update-gantt", ({ tasks }) => {
      if (tasks.length === 0) return
      if (this.gantt) {
        this.gantt.refresh(tasks)
      } else {
        this.initGantt(tasks)
      }
    })

    this.handleEvent("set-view-mode", ({ mode }) => {
      this.viewMode = mode
      if (this.gantt) this.gantt.change_view_mode(mode)
    })
  },

  updated() {
    const tasks = this._parseTasks()
    if (tasks.length === 0) return
    if (this.gantt) {
      this.gantt.refresh(tasks)
    } else {
      this.initGantt(tasks)
    }
  },

  initGantt(tasks) {
    tasks = tasks || this._parseTasks()
    if (tasks.length === 0) return

    const container = this.el.querySelector("[data-gantt-target]")
    if (!container) return

    this.gantt = new Gantt(container, tasks, {
      view_mode: this.viewMode,
      on_date_change: (task, start, end) => {
        this.pushEvent("gantt-date-change", {
          task_id: task.id,
          start: this._formatDate(start),
          end: this._formatDate(end)
        })
      },
      on_click: (task) => {
        this.pushEvent("gantt-task-click", { task_id: task.id })
      },
      popup: (ctrl) => {
        const t = ctrl.task
        ctrl.set_title(t.name)
        ctrl.set_subtitle(t.custom_popup || "")
      }
    })
  },

  _parseTasks() {
    try {
      return JSON.parse(this.el.dataset.tasks || "[]")
    } catch (_) {
      return []
    }
  },

  _formatDate(date) {
    if (!date) return null
    const d = date instanceof Date ? date : new Date(date)
    return d.toISOString().split("T")[0]
  }
}

export default GanttHook
