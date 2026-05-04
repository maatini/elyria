defmodule TaskboardWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TaskboardWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  def app(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="main-drawer" type="checkbox" class="drawer-toggle" />

      <%!-- Main content --%>
      <div class="drawer-content flex flex-col min-h-screen">
        <%!-- Mobile header --%>
        <header class="navbar bg-base-200 border-b border-base-300 px-3 lg:hidden sticky top-0 z-30">
          <label for="main-drawer" class="btn btn-ghost btn-sm drawer-button">
            <.icon name="hero-bars-3" class="size-5" />
          </label>
          <div class="flex-1 flex justify-center">
            <span class="font-bold text-lg">
              <span class="text-primary">⬡</span> Taskboard
            </span>
          </div>
          <.theme_toggle />
        </header>

        <main class="flex-1">
          {@inner_content}
        </main>

        <.flash_group flash={@flash} />
      </div>

      <%!-- Sidebar --%>
      <div class="drawer-side z-40">
        <label for="main-drawer" aria-label="Menü schließen" class="drawer-overlay"></label>

        <aside class="w-60 min-h-full bg-base-200 border-r border-base-300 flex flex-col">
          <%!-- Logo --%>
          <div class="h-16 flex items-center px-5 border-b border-base-300 shrink-0">
            <.link navigate={~p"/dashboard"} class="flex items-center gap-2.5 font-bold text-lg">
              <span class="text-primary text-xl leading-none">⬡</span>
              <span>Taskboard</span>
            </.link>
          </div>

          <%!-- Navigation --%>
          <nav class="flex-1 overflow-y-auto p-3">
            <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider px-3 mb-2 mt-1">
              Navigation
            </p>
            <ul class="space-y-0.5">
              <li>
                <.link
                  navigate={~p"/dashboard"}
                  class={[
                    "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                    if(active_for?(assigns, [TaskboardWeb.DashboardLive]),
                      do: "bg-primary text-primary-content",
                      else: "hover:bg-base-300 text-base-content"
                    )
                  ]}
                >
                  <.icon name="hero-squares-2x2" class="size-5 shrink-0" /> Dashboard
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/my-tasks"}
                  class={[
                    "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                    if(active_for?(assigns, [TaskboardWeb.MyTasksLive]),
                      do: "bg-primary text-primary-content",
                      else: "hover:bg-base-300 text-base-content"
                    )
                  ]}
                >
                  <.icon name="hero-clipboard-document-check" class="size-5 shrink-0" />
                  Meine Aufgaben
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/projects"}
                  class={[
                    "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                    if(
                      active_for?(assigns, [
                        TaskboardWeb.ProjectsLive,
                        TaskboardWeb.ProjectGanttLive
                      ]),
                      do: "bg-primary text-primary-content",
                      else: "hover:bg-base-300 text-base-content"
                    )
                  ]}
                >
                  <.icon name="hero-folder-open" class="size-5 shrink-0" /> Projekte
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/templates"}
                  class={[
                    "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                    if(active_for?(assigns, [TaskboardWeb.TemplatesLive]),
                      do: "bg-primary text-primary-content",
                      else: "hover:bg-base-300 text-base-content"
                    )
                  ]}
                >
                  <.icon name="hero-document-duplicate" class="size-5 shrink-0" /> Vorlagen
                </.link>
              </li>
            </ul>
          </nav>

          <%!-- Footer: Theme + User --%>
          <div class="p-3 border-t border-base-300 space-y-2 shrink-0">
            <.theme_toggle />

            <div :if={assigns[:current_user]} class="dropdown dropdown-top w-full">
              <div tabindex="0" role="button" class="btn btn-ghost btn-sm w-full justify-start gap-2">
                <div class="size-7 rounded-full bg-primary/15 flex items-center justify-center shrink-0">
                  <.icon name="hero-user-micro" class="size-4 text-primary" />
                </div>
                <span class="text-xs truncate flex-1 text-left">
                  {assigns[:current_user].email}
                </span>
                <.icon name="hero-chevron-up-mini" class="size-3 shrink-0" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu bg-base-100 rounded-box z-50 w-52 p-2 shadow-lg border border-base-300 mb-1"
              >
                <li class="menu-title text-xs">
                  <span class="truncate block">{assigns[:current_user].email}</span>
                </li>
                <li><.link navigate={~p"/admin"}>Admin</.link></li>
                <li>
                  <.link href={~p"/sign-out"} method="delete" class="text-error">
                    Abmelden
                  </.link>
                </li>
              </ul>
            </div>

            <div :if={!assigns[:current_user]}>
              <.link navigate={~p"/sign-in"} class="btn btn-primary btn-sm w-full">
                Anmelden
              </.link>
            </div>
          </div>
        </aside>
      </div>
    </div>
    """
  end

  defp active_for?(assigns, view_modules) do
    current_view = assigns[:socket] && Map.get(assigns[:socket], :view)
    current_view in view_modules
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
