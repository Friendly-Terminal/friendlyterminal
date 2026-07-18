import "@xterm/xterm/css/xterm.css";
import type { AppCommand, DirectoryListing, FileEntry, GitStatus, TerminalDataEvent, TerminalExitEvent } from "../shared/api";
import { helpCategories, searchCommands, searchHelpCatalog, defaultEnabledHelpCategoryIds } from "./catalog";
import type { CommandDefinition, HelpCategory, HelpCommandItem, HelpSearchHit } from "./catalog";
import { TerminalPane } from "./terminal-pane";
import type { TerminalPaneEvents } from "./terminal-pane";

interface Workspace {
  id: string;
  title: string;
  element: HTMLElement;
  tab: HTMLButtonElement;
  panes: TerminalPane[];
  activePane: TerminalPane;
}

interface HistoryEntry {
  command: string;
  exitCode: number | null;
  ranAt: number;
}

interface Preferences {
  fontSize: number;
  showHidden: boolean;
  confirmClose: boolean;
}

const defaultPreferences: Preferences = { fontSize: 14, showHidden: false, confirmClose: true };
const maximumPanes = 4;
const maximumHistoryEntries = 100;

const folderIcon = `<svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M1.5 3.5a1 1 0 0 1 1-1h3.4l1.1 1.4h6.5a1 1 0 0 1 1 1v7.1a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1v-8.5z"/></svg>`;
const fileIcon = `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.1" stroke-linejoin="round" aria-hidden="true"><path d="M3.5 1.5h6l3 3v9a1 1 0 0 1-1 1h-8a1 1 0 0 1-1-1v-11a1 1 0 0 1 1-1z"/><path d="M9.5 1.5v3h3"/></svg>`;
const gitBranchIcon = `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" aria-hidden="true"><circle cx="4" cy="3.5" r="1.8"/><circle cx="4" cy="12.5" r="1.8"/><circle cx="12" cy="6.5" r="1.8"/><path d="M4 5.3V10.7M4 7c0 2 1.5 3 4 3h2.2M12 8.3V6.5"/></svg>`;
const warningTriangleIcon = `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 2.2L14.5 13H1.5z"/><line x1="8" y1="6.3" x2="8" y2="9.3"/><line x1="8" y1="11.2" x2="8" y2="11.3"/></svg>`;
const searchGlassIcon = `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="6.5" cy="6.5" r="4"/><line x1="9.5" y1="9.5" x2="13.5" y2="13.5"/></svg>`;
const dashedSquareIcon = `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="2.5 2" aria-hidden="true"><rect x="2" y="2" width="12" height="12" rx="1.5"/></svg>`;

type HelpView = "grid" | "category" | "search";

interface HelpState {
  view: HelpView;
  selectedCategory: HelpCategory | null;
  searchQuery: string;
  searchValue: string;
}

interface TourStep {
  targetId: string | null;
  symbol: string;
  title: string;
  message: string;
}

const tourSteps: TourStep[] = [
  {
    targetId: null,
    symbol: "›_",
    title: "Welcome to FriendlyTerminal",
    message: "A friendlier way to use the terminal. Here’s a quick 30-second tour of the main parts — you can skip it anytime."
  },
  {
    targetId: "command-dock",
    symbol: ">_",
    title: "Run commands here",
    message: "Type a command and press Enter to run it in your active terminal. Press Ctrl+K whenever you want to jump back here."
  },
  {
    targetId: "files-panel",
    symbol: "▤",
    title: "Browse your files",
    message: "This shows the folder you’re currently in. Double-click a folder to move into it, or a file to open it — no command needed."
  },
  {
    targetId: "help-panel",
    symbol: "✦",
    title: "Find the right command",
    message: "Not sure what to type? Search or browse common commands by category, then choose one to drop it into the command bar."
  },
  {
    targetId: "breadcrumbs",
    symbol: "/",
    title: "Know where you are",
    message: "This trail shows the folder you’re in. Choose any part of it to jump straight to that folder."
  },
  {
    targetId: "split-pane",
    symbol: "▥",
    title: "Work side by side",
    message: "Open another terminal beside this one when you want to do two things at once. You can have up to four panes in a tab."
  },
  {
    targetId: null,
    symbol: "✓",
    title: "You’re all set",
    message: "That’s the tour. You can replay it anytime from Settings → Show tour. Happy exploring!"
  }
];

function categoryIconSvg(inner: string): string {
  return `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${inner}</svg>`;
}

class FriendlyTerminalApp {
  private readonly panes = new Map<string, TerminalPane>();
  private readonly workspaces: Workspace[] = [];
  private readonly history: HistoryEntry[];
  private preferences: Preferences;
  private activeWorkspace: Workspace | null = null;
  private readonly pendingCommands = new Map<string, HistoryEntry>();
  private refreshSequence = 0;

  private helpView: HelpView = "grid";
  private helpSelectedCategory: HelpCategory | null = null;
  private helpSearchQuery = "";
  private readonly enabledHelpCategories = new Set(
    readStringArray("friendlyterminal.helpCategories", defaultEnabledHelpCategoryIds)
  );

  private readonly root = requiredElement<HTMLElement>("app");
  private readonly tabs = requiredElement<HTMLElement>("tabs");
  private readonly workspacesHost = requiredElement<HTMLElement>("workspaces");
  private readonly breadcrumbs = requiredElement<HTMLElement>("breadcrumbs");
  private readonly fileList = requiredElement<HTMLElement>("file-list");
  private readonly gitPill = requiredElement<HTMLButtonElement>("git-pill");
  private readonly gitPopover = requiredElement<HTMLElement>("git-popover");
  private readonly gitDetails = requiredElement<HTMLElement>("git-details");
  private readonly historyBlock = requiredElement<HTMLElement>("history-block");
  private readonly historyList = requiredElement<HTMLElement>("history-list");
  private readonly helpSearch = requiredElement<HTMLInputElement>("help-search");
  private readonly helpSearchWrap = requiredElement<HTMLElement>("help-search-wrap");
  private readonly helpResults = requiredElement<HTMLElement>("help-results");
  private readonly helpBack = requiredElement<HTMLButtonElement>("help-back");
  private readonly helpTitle = requiredElement<HTMLElement>("help-title");
  private readonly helpSettingsDialog = requiredElement<HTMLDialogElement>("help-settings-dialog");
  private readonly helpSettingsList = requiredElement<HTMLElement>("help-settings-list");
  private readonly commandInput = requiredElement<HTMLInputElement>("command-input");
  private readonly commandDialog = requiredElement<HTMLDialogElement>("command-dialog");
  private readonly commandSearch = requiredElement<HTMLInputElement>("command-search");
  private readonly commandResults = requiredElement<HTMLElement>("command-results");
  private readonly settingsDialog = requiredElement<HTMLDialogElement>("settings-dialog");
  private readonly tourOverlay = requiredElement<HTMLElement>("welcome-tour");
  private readonly tourCard = requiredElement<HTMLElement>("tour-card");
  private readonly tourSpotlight = requiredElement<HTMLElement>("tour-spotlight");
  private tourStepIndex = 0;
  private tourActive = false;
  private tourOpenedSidebar = false;
  private tourPreviousFocus: HTMLElement | null = null;
  private tourPreviousHelpState: HelpState | null = null;
  private tourShowingHelpGrid = false;
  private tourResizeObserver: ResizeObserver | null = null;
  private tourLayoutFrame: number | null = null;
  private readonly handleTourGeometryChange = (): void => this.layoutTour();
  private readonly terminalSearch = requiredElement<HTMLElement>("terminal-search");
  private readonly terminalSearchInput = requiredElement<HTMLInputElement>("terminal-search-input");

  constructor() {
    this.preferences = readJson<Preferences>("friendlyterminal.preferences", defaultPreferences);
    this.history = readJson<HistoryEntry[]>("friendlyterminal.history", []);
  }

  async start(): Promise<void> {
    this.bindControls();
    this.bindIpc();
    this.applyPreferences();
    this.renderHistory();
    this.buildHelpSettings();
    this.renderHelp();
    await this.createWorkspace();
    requiredElement("loading").remove();
    if (localStorage.getItem("friendlyterminal.welcomed") !== "true") {
      this.startTour();
    }
    const version = await window.friendlyTerminal.app.version();
    requiredElement("app-version").textContent = `v${version}`;
  }

  private bindControls(): void {
    requiredElement("new-tab").addEventListener("click", () => void this.createWorkspace());
    requiredElement("split-pane").addEventListener("click", () => void this.splitPane());
    requiredElement("sidebar-toggle").addEventListener("click", () => this.toggleSidebar());
    requiredElement("open-palette").addEventListener("click", () => this.openCommandPalette());
    requiredElement("command-help").addEventListener("click", () => this.openCommandPalette());
    requiredElement("open-guide").addEventListener("click", () => this.openCommandPalette());
    requiredElement("run-command").addEventListener("click", () => this.runCommandBar());
    requiredElement("open-settings").addEventListener("click", () => this.openSettings());
    requiredElement("refresh-files").addEventListener("click", () => void this.refreshContext());
    requiredElement("clear-history").addEventListener("click", () => this.clearHistory());
    requiredElement("find-terminal").addEventListener("click", () => this.openTerminalSearch());
    requiredElement("terminal-search-next").addEventListener("click", () => this.searchTerminal());
    requiredElement("terminal-search-close").addEventListener("click", () => this.closeTerminalSearch());
    requiredElement("show-welcome-tour").addEventListener("click", () => {
      this.settingsDialog.close();
      this.startTour();
    });
    requiredElement("tour-next").addEventListener("click", () => this.advanceTour());
    requiredElement("tour-back").addEventListener("click", () => this.goBackInTour());
    requiredElement("tour-skip").addEventListener("click", () => this.finishTour());
    this.tourOverlay.addEventListener("keydown", (event) => this.handleTourKeydown(event));
    this.commandInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        this.runCommandBar();
      } else if (event.key === "Escape") {
        this.commandInput.value = "";
        this.activePane?.focus();
      }
    });
    this.commandSearch.addEventListener("input", () => this.renderCommandResults(this.commandSearch.value));
    this.helpSearch.addEventListener("input", () => {
      this.helpSearchQuery = this.helpSearch.value;
      this.helpView = this.helpSearchQuery.trim() ? "search" : "grid";
      this.renderHelp();
    });
    this.helpBack.addEventListener("click", () => {
      this.helpSelectedCategory = null;
      this.helpView = "grid";
      this.renderHelp();
    });
    requiredElement("help-settings").addEventListener("click", () => this.openHelpSettings());
    requiredElement("help-settings-done").addEventListener("click", () => this.helpSettingsDialog.close());
    this.helpSettingsDialog.addEventListener("close", () => {
      this.syncDrilledInCategory();
      this.renderHelp();
    });
    this.gitPill.addEventListener("click", () => this.toggleGitPopover());
    this.terminalSearchInput.addEventListener("input", () => this.searchTerminal());
    this.terminalSearchInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        this.searchTerminal();
      } else if (event.key === "Escape") {
        this.closeTerminalSearch();
      }
    });
    document.querySelectorAll<HTMLElement>(".dialog-close").forEach((button) => {
      button.addEventListener("click", () => button.closest("dialog")?.close());
    });
    document.addEventListener("click", (event) => {
      const target = event.target as Node;
      if (!this.gitPopover.hidden && !this.gitPopover.contains(target) && !this.gitPill.contains(target)) {
        this.setGitPopover(false);
      }
    });
    const showHidden = requiredElement<HTMLInputElement>("show-hidden");
    showHidden.addEventListener("change", () => {
      this.updatePreference("showHidden", showHidden.checked);
      requiredElement<HTMLInputElement>("settings-show-hidden").checked = showHidden.checked;
      void this.refreshFiles();
    });
    requiredElement<HTMLInputElement>("settings-show-hidden").addEventListener("change", (event) => {
      const checked = (event.currentTarget as HTMLInputElement).checked;
      this.updatePreference("showHidden", checked);
      showHidden.checked = checked;
      void this.refreshFiles();
    });
    requiredElement<HTMLInputElement>("confirm-close").addEventListener("change", (event) => {
      this.updatePreference("confirmClose", (event.currentTarget as HTMLInputElement).checked);
    });
    requiredElement<HTMLInputElement>("font-size").addEventListener("input", (event) => {
      const fontSize = Number.parseInt((event.currentTarget as HTMLInputElement).value, 10);
      this.updateFontSize(fontSize);
    });
    document.addEventListener("keydown", (event) => this.handleShortcut(event));
  }

  private bindIpc(): void {
    window.friendlyTerminal.terminal.onData((event: TerminalDataEvent) => this.panes.get(event.id)?.receiveData(event.data));
    window.friendlyTerminal.terminal.onExit((event: TerminalExitEvent) => this.panes.get(event.id)?.receiveExit(event));
    window.friendlyTerminal.app.onCommand((command) => this.handleAppCommand(command));
  }

  private async createWorkspace(cwd?: string): Promise<void> {
    const element = document.createElement("div");
    element.className = "terminal-grid";
    element.hidden = true;
    const tab = document.createElement("button");
    tab.className = "tab";
    tab.type = "button";
    const provisionalWorkspace = { id: crypto.randomUUID(), title: "Terminal", element, tab };
    const events = this.paneEvents();
    try {
      const pane = await TerminalPane.create(cwd, this.preferences.fontSize, events);
      const workspace: Workspace = { ...provisionalWorkspace, panes: [pane], activePane: pane, title: compactFolderName(pane.cwd) };
      tab.innerHTML = `<span class="tab-status" aria-hidden="true"></span><span class="tab-title"></span><span class="tab-close" role="button" aria-label="Close tab">×</span>`;
      tab.querySelector<HTMLElement>(".tab-title")!.textContent = workspace.title;
      tab.addEventListener("click", (event) => {
        if ((event.target as HTMLElement).closest(".tab-close")) {
          void this.closeWorkspace(workspace);
        } else {
          this.activateWorkspace(workspace);
        }
      });
      tab.addEventListener("auxclick", (event) => {
        if (event.button === 1) {
          void this.closeWorkspace(workspace);
        }
      });
      this.workspaces.push(workspace);
      this.tabs.append(tab);
      this.workspacesHost.append(element);
      this.panes.set(pane.id, pane);
      pane.mount(element);
      this.activateWorkspace(workspace);
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : "The shell could not be started", "error");
    }
  }

  private async splitPane(): Promise<void> {
    const workspace = this.activeWorkspace;
    if (!workspace) {
      return;
    }
    if (workspace.panes.length >= maximumPanes) {
      this.showToast(`A workspace can contain up to ${maximumPanes} panes`, "info");
      return;
    }
    try {
      const pane = await TerminalPane.create(workspace.activePane.cwd, this.preferences.fontSize, this.paneEvents());
      workspace.panes.push(pane);
      this.panes.set(pane.id, pane);
      pane.mount(workspace.element);
      this.updateGridLayout(workspace);
      this.activatePane(workspace, pane);
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : "A new pane could not be opened", "error");
    }
  }

  private paneEvents(): TerminalPaneEvents {
    return {
      onActivate: (pane) => {
        const workspace = this.findWorkspace(pane);
        if (workspace) {
          this.activatePane(workspace, pane);
        }
      },
      onClose: (pane) => void this.closePane(pane),
      onCwdChange: (pane, cwd) => this.handleCwdChange(pane, cwd),
      onCommand: (pane, command) => this.handleCommandStart(pane, command),
      onCommandEnd: (pane, exitCode) => this.handleCommandEnd(pane, exitCode)
    };
  }

  private activateWorkspace(workspace: Workspace): void {
    for (const candidate of this.workspaces) {
      candidate.element.hidden = candidate !== workspace;
      candidate.tab.classList.toggle("active", candidate === workspace);
      candidate.tab.setAttribute("aria-selected", String(candidate === workspace));
    }
    this.activeWorkspace = workspace;
    this.activatePane(workspace, workspace.activePane);
  }

  private activatePane(workspace: Workspace, pane: TerminalPane): void {
    if (this.activeWorkspace !== workspace) {
      this.activateWorkspace(workspace);
      return;
    }
    workspace.activePane = pane;
    for (const candidate of workspace.panes) {
      if (candidate === pane) {
        candidate.activate();
      } else {
        candidate.deactivate();
      }
    }
    void this.refreshContext();
  }

  private async closePane(pane: TerminalPane): Promise<void> {
    const workspace = this.findWorkspace(pane);
    if (!workspace) {
      return;
    }
    if (workspace.panes.length === 1) {
      await this.closeWorkspace(workspace);
      return;
    }
    if (!this.canClose()) {
      return;
    }
    const index = workspace.panes.indexOf(pane);
    workspace.panes.splice(index, 1);
    this.panes.delete(pane.id);
    await pane.dispose();
    this.updateGridLayout(workspace);
    this.activatePane(workspace, workspace.panes[Math.max(0, index - 1)]!);
  }

  private async closeWorkspace(workspace: Workspace): Promise<void> {
    if (!this.canClose()) {
      return;
    }
    const index = this.workspaces.indexOf(workspace);
    if (this.workspaces.length === 1) {
      await this.createWorkspace(workspace.activePane.cwd);
      if (this.workspaces.length === 1) {
        this.showToast("The current terminal stayed open because a replacement shell could not start", "error");
        return;
      }
    }
    this.workspaces.splice(this.workspaces.indexOf(workspace), 1);
    workspace.tab.remove();
    workspace.element.remove();
    for (const pane of workspace.panes) {
      this.panes.delete(pane.id);
      await pane.dispose();
    }
    if (this.activeWorkspace === workspace) {
      const nextWorkspace = this.workspaces[Math.min(index, this.workspaces.length - 1)];
      if (nextWorkspace) {
        this.activateWorkspace(nextWorkspace);
      }
    }
  }

  private canClose(): boolean {
    return !this.preferences.confirmClose || window.confirm("Close this terminal? Any running process in it will stop.");
  }

  private updateGridLayout(workspace: Workspace): void {
    workspace.element.dataset.panes = String(workspace.panes.length);
  }

  private handleCwdChange(pane: TerminalPane, cwd: string): void {
    const workspace = this.findWorkspace(pane);
    if (!workspace) {
      return;
    }
    workspace.title = compactFolderName(cwd);
    workspace.tab.querySelector<HTMLElement>(".tab-title")!.textContent = workspace.title;
    if (workspace === this.activeWorkspace && pane === workspace.activePane) {
      void this.refreshContext();
    }
  }

  private handleCommandStart(pane: TerminalPane, command: string): void {
    const workspace = this.findWorkspace(pane);
    if (!workspace) {
      return;
    }
    this.pendingCommands.set(pane.id, { command, exitCode: null, ranAt: Date.now() });
    workspace.tab.classList.add("busy");
  }

  private handleCommandEnd(pane: TerminalPane, exitCode: number): void {
    const workspace = this.findWorkspace(pane);
    workspace?.tab.classList.remove("busy");
    const entry = this.pendingCommands.get(pane.id);
    if (entry) {
      entry.exitCode = exitCode;
      this.history.unshift(entry);
      this.pendingCommands.delete(pane.id);
      this.history.splice(maximumHistoryEntries);
      localStorage.setItem("friendlyterminal.history", JSON.stringify(this.history));
      this.renderHistory();
    }
    if (workspace === this.activeWorkspace && pane === workspace.activePane) {
      void this.refreshContext();
    }
  }

  private async refreshContext(): Promise<void> {
    const sequence = ++this.refreshSequence;
    this.renderBreadcrumbs();
    await Promise.all([this.refreshFiles(sequence), this.refreshGit(sequence)]);
  }

  private async refreshFiles(sequence = this.refreshSequence): Promise<void> {
    const pane = this.activePane;
    if (!pane) {
      return;
    }
    this.fileList.innerHTML = `<div class="panel-loading">Loading files…</div>`;
    try {
      const listing = await window.friendlyTerminal.files.list(pane.cwd, this.preferences.showHidden);
      if (sequence !== this.refreshSequence || pane !== this.activePane) {
        return;
      }
      this.renderFiles(listing);
    } catch (error) {
      this.fileList.innerHTML = `<div class="empty-state">${escapeHtml(error instanceof Error ? error.message : "This folder could not be read")}</div>`;
    }
  }

  private renderFiles(listing: DirectoryListing): void {
    this.fileList.replaceChildren();
    if (listing.entries.length === 0) {
      this.fileList.innerHTML = `<div class="empty-state">This folder is empty.</div>`;
      return;
    }
    for (const entry of listing.entries) {
      this.fileList.append(this.createFileRow(entry));
    }
    if (listing.truncated) {
      const message = document.createElement("div");
      message.className = "list-note";
      message.textContent = "Showing the first 1,000 items";
      this.fileList.append(message);
    }
  }

  private createFileRow(entry: FileEntry): HTMLElement {
    const row = document.createElement("button");
    row.type = "button";
    row.className = "file-row";
    row.innerHTML = `<span class="file-icon ${entry.isDirectory ? "folder" : "file"}" aria-hidden="true">${entry.isDirectory ? folderIcon : fileIcon}</span><span class="file-name"></span><span class="file-meta"></span>`;
    row.querySelector<HTMLElement>(".file-name")!.textContent = entry.name;
    row.querySelector<HTMLElement>(".file-meta")!.textContent = entry.isDirectory ? "" : formatBytes(entry.size);
    row.title = entry.path;
    row.addEventListener("dblclick", () => {
      if (entry.isDirectory) {
        this.activePane?.navigate(entry.path);
      } else {
        void window.friendlyTerminal.files.open(entry.path).then((error) => {
          if (error) {
            this.showToast(error, "error");
          }
        });
      }
    });
    row.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      window.friendlyTerminal.files.reveal(entry.path);
    });
    return row;
  }

  private async refreshGit(sequence = this.refreshSequence): Promise<void> {
    const pane = this.activePane;
    if (!pane) {
      return;
    }
    const status = await window.friendlyTerminal.git.status(pane.cwd);
    if (sequence !== this.refreshSequence || pane !== this.activePane) {
      return;
    }
    this.renderGit(status);
  }

  private renderGit(status: GitStatus | null): void {
    if (!status) {
      this.gitPill.hidden = true;
      this.setGitPopover(false);
      this.gitDetails.className = "empty-state";
      this.gitDetails.textContent = "This folder is not inside a Git repository.";
      return;
    }
    this.gitPill.hidden = false;
    this.gitPill.innerHTML = `${gitBranchIcon}<span>${escapeHtml(status.branch)}${status.changedFiles > 0 ? ` · ${status.changedFiles} changed` : " · clean"}</span>`;
    const syncParts = [status.ahead > 0 ? `${status.ahead} ahead` : "", status.behind > 0 ? `${status.behind} behind` : ""].filter(Boolean).join(" · ");
    this.gitDetails.className = "git-card";
    this.gitDetails.innerHTML = `
      <div class="git-branch">${gitBranchIcon}<strong>${escapeHtml(status.branch)}</strong></div>
      <div class="git-summary ${status.changedFiles === 0 ? "clean" : "changed"}">${status.changedFiles === 0 ? "Working tree is clean" : `${status.changedFiles} changed file${status.changedFiles === 1 ? "" : "s"}`}</div>
      ${syncParts ? `<div class="git-sync">${escapeHtml(syncParts)}</div>` : ""}
      <div class="git-actions"><button type="button" data-command="git status">Status</button><button type="button" data-command="git diff">Review changes</button><button type="button" data-command="git log --oneline --graph -20">History</button></div>
    `;
    this.gitDetails.querySelectorAll<HTMLButtonElement>("[data-command]").forEach((button) => {
      button.addEventListener("click", () => this.fillCommand(button.dataset.command ?? ""));
    });
  }

  private renderBreadcrumbs(): void {
    const pane = this.activePane;
    this.breadcrumbs.replaceChildren();
    if (!pane) {
      return;
    }
    const segments = pane.cwd.split("/").filter(Boolean);
    const paths = ["/", ...segments.map((_segment, index) => `/${segments.slice(0, index + 1).join("/")}`)];
    const labels = ["/", ...segments];
    paths.forEach((path, index) => {
      if (index > 0) {
        const separator = document.createElement("span");
        separator.className = "breadcrumb-separator";
        separator.textContent = "›";
        this.breadcrumbs.append(separator);
      }
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = labels[index] ?? path;
      button.title = path;
      button.addEventListener("click", () => pane.navigate(path));
      this.breadcrumbs.append(button);
    });
    this.breadcrumbs.lastElementChild?.scrollIntoView({ inline: "end" });
  }

  private runCommandBar(): void {
    const command = this.commandInput.value.trim();
    if (!command || !this.activePane) {
      return;
    }
    this.activePane.run(command);
    this.commandInput.value = "";
    this.activePane.focus();
  }

  private fillCommand(command: string): void {
    this.commandInput.value = command;
    this.commandDialog.close();
    this.setGitPopover(false);
    this.commandInput.focus();
    this.commandInput.setSelectionRange(command.length, command.length);
  }

  private openCommandPalette(): void {
    this.setGitPopover(false);
    this.commandSearch.value = "";
    this.renderCommandResults("");
    this.commandDialog.showModal();
    queueMicrotask(() => this.commandSearch.focus());
  }

  private renderCommandResults(query: string): void {
    this.historyBlock.hidden = query.trim().length > 0 || this.history.length === 0;
    const matches = searchCommands(query);
    if (matches.length === 0) {
      this.commandResults.replaceChildren();
      this.commandResults.innerHTML = `<div class="empty-state large">No matching commands. Try describing the outcome in different words.</div>`;
      return;
    }
    this.renderCommandGroups(matches, this.commandResults);
  }

  private renderHelp(): void {
    this.helpBack.hidden = this.helpView !== "category";
    this.helpTitle.textContent =
      this.helpView === "category" && this.helpSelectedCategory ? this.helpSelectedCategory.name : "Help with…";
    this.helpSearchWrap.hidden = this.helpView === "category";

    if (this.helpView === "category" && this.helpSelectedCategory) {
      const category = this.helpSelectedCategory;
      this.renderHelpRows(
        category.commands.map((item) => ({ category, item })),
        false,
        "Tap a command to drop it into the command bar."
      );
      return;
    }

    if (this.helpView === "search") {
      const hits = searchHelpCatalog(this.helpSearchQuery);
      if (hits.length === 0) {
        this.renderHelpEmpty(searchGlassIcon, `No commands match "${this.helpSearchQuery.trim()}".`);
        return;
      }
      this.renderHelpRows(hits, true);
      return;
    }

    const visible = helpCategories.filter((category) =>
      this.tourShowingHelpGrid
        ? defaultEnabledHelpCategoryIds.includes(category.id)
        : this.enabledHelpCategories.has(category.id)
    );
    if (visible.length === 0) {
      this.renderHelpEmpty(dashedSquareIcon, "No command groups shown.", true);
      return;
    }
    this.renderHelpGrid(visible);
  }

  private renderHelpGrid(categories: HelpCategory[]): void {
    const grid = document.createElement("div");
    grid.className = "help-category-grid";
    for (const category of categories) {
      const tile = document.createElement("button");
      tile.type = "button";
      tile.className = "help-category-tile";
      tile.innerHTML = `${categoryIconSvg(category.icon)}<span></span>`;
      tile.querySelector("span")!.textContent = category.name;
      tile.addEventListener("click", () => {
        this.helpSelectedCategory = category;
        this.helpView = "category";
        this.renderHelp();
      });
      grid.append(tile);
    }
    this.helpResults.replaceChildren(grid);
  }

  private renderHelpRows(hits: HelpSearchHit[], showChip: boolean, hint?: string): void {
    const list = document.createElement("div");
    list.className = "help-command-list";
    if (hint) {
      const hintEl = document.createElement("p");
      hintEl.className = "help-hint";
      hintEl.textContent = hint;
      list.append(hintEl);
    }
    for (const { category, item } of hits) {
      list.append(this.createHelpRow(item, showChip ? category.name : null));
    }
    this.helpResults.replaceChildren(list);
  }

  private createHelpRow(item: HelpCommandItem, chipCategory: string | null): HTMLButtonElement {
    const button = document.createElement("button");
    button.type = "button";
    button.className = item.dangerous ? "command-result dangerous" : "command-result";
    const head = document.createElement("span");
    head.className = "command-row-head";
    head.innerHTML = item.dangerous ? warningTriangleIcon : "";
    const code = document.createElement("code");
    code.textContent = item.command;
    head.append(code);
    if (chipCategory) {
      const chip = document.createElement("span");
      chip.className = "category-chip";
      chip.textContent = chipCategory;
      head.append(chip);
    }
    const detail = document.createElement("span");
    detail.textContent = item.detail;
    button.append(head, detail);
    if (item.dangerous) {
      const label = document.createElement("strong");
      label.className = "danger-label";
      label.textContent = "Careful";
      button.append(label);
    }
    button.addEventListener("click", () => this.fillCommand(item.command));
    return button;
  }

  private renderHelpEmpty(icon: string, message: string, withChooseButton = false): void {
    const empty = document.createElement("div");
    empty.className = "empty-state help-empty";
    empty.innerHTML = icon;
    const text = document.createElement("p");
    text.textContent = message;
    empty.append(text);
    if (withChooseButton) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = "Choose groups…";
      button.addEventListener("click", () => this.openHelpSettings());
      empty.append(button);
    }
    this.helpResults.replaceChildren(empty);
  }

  private buildHelpSettings(): void {
    this.helpSettingsList.replaceChildren();
    for (const category of helpCategories) {
      const row = document.createElement("label");
      row.className = "help-category-row";
      const icon = document.createElement("span");
      icon.className = "help-category-icon";
      icon.setAttribute("aria-hidden", "true");
      icon.innerHTML = categoryIconSvg(category.icon);
      const copy = document.createElement("span");
      copy.className = "help-category-copy";
      const name = document.createElement("strong");
      name.textContent = category.name;
      const count = document.createElement("small");
      count.textContent = `${category.commands.length} command${category.commands.length === 1 ? "" : "s"}`;
      copy.append(name, count);
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.dataset.categoryId = category.id;
      checkbox.addEventListener("change", () => this.toggleHelpCategory(category.id, checkbox.checked));
      row.append(icon, copy, checkbox);
      this.helpSettingsList.append(row);
    }
  }

  private openHelpSettings(): void {
    this.helpSettingsList.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach((checkbox) => {
      checkbox.checked = this.enabledHelpCategories.has(checkbox.dataset.categoryId ?? "");
    });
    this.helpSettingsDialog.showModal();
  }

  private toggleHelpCategory(id: string, enabled: boolean): void {
    if (enabled) {
      this.enabledHelpCategories.add(id);
    } else {
      this.enabledHelpCategories.delete(id);
    }
    this.saveEnabledHelpCategories();
    this.syncDrilledInCategory();
    this.renderHelp();
  }

  private syncDrilledInCategory(): void {
    if (
      this.helpView === "category" &&
      this.helpSelectedCategory &&
      !this.enabledHelpCategories.has(this.helpSelectedCategory.id)
    ) {
      this.helpSelectedCategory = null;
      this.helpView = "grid";
    }
  }

  private saveEnabledHelpCategories(): void {
    localStorage.setItem("friendlyterminal.helpCategories", JSON.stringify([...this.enabledHelpCategories]));
  }

  private renderCommandGroups(matches: CommandDefinition[], container: HTMLElement): void {
    container.replaceChildren();
    const grouped = new Map<string, CommandDefinition[]>();
    for (const command of matches) {
      const group = grouped.get(command.category) ?? [];
      group.push(command);
      grouped.set(command.category, group);
    }
    for (const [category, commands] of grouped) {
      const section = document.createElement("section");
      section.className = "command-group";
      section.innerHTML = `<h2>${escapeHtml(category)}</h2>`;
      for (const command of commands) {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "command-result";
        button.innerHTML = `<code></code><span></span>${command.dangerous ? '<strong class="danger-label">Careful</strong>' : ""}`;
        button.querySelector("code")!.textContent = command.command;
        button.querySelector("span")!.textContent = command.description;
        button.addEventListener("click", () => this.fillCommand(command.command));
        section.append(button);
      }
      container.append(section);
    }
  }

  private renderHistory(): void {
    this.historyList.replaceChildren();
    this.historyBlock.hidden = this.commandSearch.value.trim().length > 0 || this.history.length === 0;
    if (this.history.length === 0) {
      this.historyList.innerHTML = `<div class="empty-state">Commands you run will appear here for quick reuse.</div>`;
      return;
    }
    for (const entry of this.history) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "history-row";
      button.innerHTML = `<span class="history-status ${entry.exitCode === 0 ? "success" : "failure"}" aria-label="${entry.exitCode === 0 ? "Succeeded" : "Failed"}"></span><code></code><time></time>`;
      button.querySelector("code")!.textContent = entry.command;
      button.querySelector("time")!.textContent = relativeTime(entry.ranAt);
      button.addEventListener("click", () => this.fillCommand(entry.command));
      this.historyList.append(button);
    }
  }

  private clearHistory(): void {
    this.history.splice(0);
    localStorage.removeItem("friendlyterminal.history");
    this.renderHistory();
  }

  private openSettings(): void {
    requiredElement<HTMLInputElement>("font-size").value = String(this.preferences.fontSize);
    requiredElement("font-size-output").textContent = `${this.preferences.fontSize}px`;
    requiredElement<HTMLInputElement>("settings-show-hidden").checked = this.preferences.showHidden;
    requiredElement<HTMLInputElement>("confirm-close").checked = this.preferences.confirmClose;
    this.settingsDialog.showModal();
  }

  private startTour(): void {
    if (this.tourActive) {
      return;
    }
    this.tourPreviousFocus = document.activeElement instanceof HTMLElement && this.root.contains(document.activeElement)
      ? document.activeElement
      : null;
    this.tourPreviousHelpState = {
      view: this.helpView,
      selectedCategory: this.helpSelectedCategory,
      searchQuery: this.helpSearchQuery,
      searchValue: this.helpSearch.value
    };
    this.tourOpenedSidebar = !this.root.classList.contains("sidebar-visible");
    this.tourStepIndex = 0;
    this.tourActive = true;
    window.addEventListener("resize", this.handleTourGeometryChange);
    this.root.addEventListener("transitionend", this.handleTourGeometryChange);
    this.tourResizeObserver = new ResizeObserver(this.handleTourGeometryChange);
    this.root.classList.add("sidebar-visible");
    this.root.inert = true;
    this.tourOverlay.hidden = false;
    this.renderTourStep();
  }

  private advanceTour(): void {
    if (this.tourStepIndex >= tourSteps.length - 1) {
      this.finishTour();
      return;
    }
    this.tourStepIndex += 1;
    this.renderTourStep();
  }

  private goBackInTour(): void {
    if (this.tourStepIndex === 0) {
      return;
    }
    this.tourStepIndex -= 1;
    this.renderTourStep();
  }

  private finishTour(): void {
    if (!this.tourActive) {
      return;
    }
    localStorage.setItem("friendlyterminal.welcomed", "true");
    this.tourActive = false;
    if (this.tourLayoutFrame !== null) {
      cancelAnimationFrame(this.tourLayoutFrame);
      this.tourLayoutFrame = null;
    }
    window.removeEventListener("resize", this.handleTourGeometryChange);
    this.root.removeEventListener("transitionend", this.handleTourGeometryChange);
    this.tourResizeObserver?.disconnect();
    this.tourResizeObserver = null;
    this.tourOverlay.hidden = true;
    this.root.inert = false;
    if (this.tourOpenedSidebar) {
      this.root.classList.remove("sidebar-visible");
    }
    const helpState = this.tourPreviousHelpState;
    this.tourPreviousHelpState = null;
    this.tourShowingHelpGrid = false;
    if (helpState) {
      this.helpView = helpState.view;
      this.helpSelectedCategory = helpState.selectedCategory;
      this.helpSearchQuery = helpState.searchQuery;
      this.helpSearch.value = helpState.searchValue;
      this.renderHelp();
    }
    const previousFocus = this.tourPreviousFocus;
    this.tourPreviousFocus = null;
    if (previousFocus?.isConnected) {
      previousFocus.focus();
    } else {
      this.activePane?.focus();
    }
  }

  private renderTourStep(): void {
    const step = tourSteps[this.tourStepIndex]!;
    if (step.targetId === "help-panel") {
      this.tourShowingHelpGrid = true;
      this.helpView = "grid";
      this.helpSelectedCategory = null;
      this.helpSearchQuery = "";
      this.helpSearch.value = "";
      this.renderHelp();
    } else if (this.tourShowingHelpGrid) {
      this.tourShowingHelpGrid = false;
      const helpState = this.tourPreviousHelpState;
      if (helpState) {
        this.helpView = helpState.view;
        this.helpSelectedCategory = helpState.selectedCategory;
        this.helpSearchQuery = helpState.searchQuery;
        this.helpSearch.value = helpState.searchValue;
        this.renderHelp();
      }
    }
    requiredElement("tour-symbol").textContent = step.symbol;
    requiredElement("tour-title").textContent = step.title;
    requiredElement("tour-message").textContent = step.message;
    requiredElement("tour-progress").textContent = `Step ${this.tourStepIndex + 1} of ${tourSteps.length}`;
    const dots = requiredElement("tour-dots");
    dots.replaceChildren(...tourSteps.map((_candidate, index) => {
      const dot = document.createElement("span");
      dot.className = index === this.tourStepIndex ? "active" : "";
      return dot;
    }));
    const isLastStep = this.tourStepIndex === tourSteps.length - 1;
    requiredElement<HTMLButtonElement>("tour-back").hidden = this.tourStepIndex === 0;
    requiredElement<HTMLButtonElement>("tour-skip").hidden = isLastStep;
    requiredElement("tour-next").textContent = isLastStep ? "Done" : "Next";
    const target = step.targetId ? document.getElementById(step.targetId) : null;
    this.tourResizeObserver?.disconnect();
    this.tourResizeObserver?.observe(this.tourCard);
    if (target) {
      this.tourResizeObserver?.observe(target);
    }
    this.tourCard.style.visibility = "hidden";
    if (this.tourLayoutFrame !== null) {
      cancelAnimationFrame(this.tourLayoutFrame);
    }
    this.tourLayoutFrame = requestAnimationFrame(() => {
      this.tourLayoutFrame = null;
      if (!this.tourActive) {
        return;
      }
      this.layoutTour();
      requiredElement<HTMLButtonElement>("tour-next").focus();
    });
  }

  private layoutTour(): void {
    if (!this.tourActive) {
      return;
    }
    const step = tourSteps[this.tourStepIndex]!;
    const target = step.targetId ? document.getElementById(step.targetId) : null;
    const targetRect = target?.getBoundingClientRect();
    const hasTarget = targetRect && targetRect.width > 0 && targetRect.height > 0;
    this.tourOverlay.classList.toggle("centered", !hasTarget);
    this.tourSpotlight.hidden = !hasTarget;

    let highlight: DOMRect | null = null;
    if (hasTarget) {
      const padding = 8;
      const left = Math.max(4, targetRect.left - padding);
      const top = Math.max(4, targetRect.top - padding);
      const right = Math.min(window.innerWidth - 4, targetRect.right + padding);
      const bottom = Math.min(window.innerHeight - 4, targetRect.bottom + padding);
      this.tourSpotlight.style.left = `${left}px`;
      this.tourSpotlight.style.top = `${top}px`;
      this.tourSpotlight.style.width = `${right - left}px`;
      this.tourSpotlight.style.height = `${bottom - top}px`;
      highlight = new DOMRect(left, top, right - left, bottom - top);
    }

    const cardRect = this.tourCard.getBoundingClientRect();
    const margin = 18;
    const gap = 18;
    const clamp = (value: number, minimum: number, maximum: number): number =>
      Math.min(Math.max(value, minimum), Math.max(minimum, maximum));
    let left = (window.innerWidth - cardRect.width) / 2;
    let top = (window.innerHeight - cardRect.height) / 2;

    if (highlight) {
      const candidates = [
        { left: highlight.x + (highlight.width - cardRect.width) / 2, top: highlight.bottom + gap, space: window.innerHeight - highlight.bottom },
        { left: highlight.x + (highlight.width - cardRect.width) / 2, top: highlight.top - gap - cardRect.height, space: highlight.top },
        { left: highlight.right + gap, top: highlight.y + (highlight.height - cardRect.height) / 2, space: window.innerWidth - highlight.right },
        { left: highlight.left - gap - cardRect.width, top: highlight.y + (highlight.height - cardRect.height) / 2, space: highlight.left }
      ];
      const fitting = candidates.find((candidate) =>
        candidate.left >= margin && candidate.top >= margin &&
        candidate.left + cardRect.width <= window.innerWidth - margin &&
        candidate.top + cardRect.height <= window.innerHeight - margin
      );
      const preferred = fitting ?? [...candidates].sort((a, b) => b.space - a.space)[0]!;
      left = preferred.left;
      top = preferred.top;
    }

    this.tourCard.style.left = `${clamp(left, margin, window.innerWidth - cardRect.width - margin)}px`;
    this.tourCard.style.top = `${clamp(top, margin, window.innerHeight - cardRect.height - margin)}px`;
    this.tourCard.style.visibility = "visible";
  }

  private handleTourKeydown(event: KeyboardEvent): void {
    event.stopPropagation();
    if (event.key === "Escape") {
      event.preventDefault();
      this.finishTour();
      return;
    }
    if (event.key === "ArrowLeft" && this.tourStepIndex > 0) {
      event.preventDefault();
      this.goBackInTour();
      return;
    }
    if (event.key === "ArrowRight") {
      event.preventDefault();
      this.advanceTour();
      return;
    }
    if (event.key !== "Tab") {
      return;
    }
    const controls = Array.from(
      this.tourCard.querySelectorAll<HTMLButtonElement>("button:not([hidden]):not(:disabled)")
    );
    const first = controls[0];
    const last = controls.at(-1);
    if (!first || !last) {
      return;
    }
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  private applyPreferences(): void {
    requiredElement<HTMLInputElement>("show-hidden").checked = this.preferences.showHidden;
    requiredElement<HTMLInputElement>("settings-show-hidden").checked = this.preferences.showHidden;
    requiredElement<HTMLInputElement>("confirm-close").checked = this.preferences.confirmClose;
    requiredElement<HTMLInputElement>("font-size").value = String(this.preferences.fontSize);
    requiredElement("font-size-output").textContent = `${this.preferences.fontSize}px`;
  }

  private updatePreference<Key extends keyof Preferences>(key: Key, value: Preferences[Key]): void {
    this.preferences = { ...this.preferences, [key]: value };
    localStorage.setItem("friendlyterminal.preferences", JSON.stringify(this.preferences));
  }

  private updateFontSize(fontSize: number): void {
    const clampedSize = Math.max(11, Math.min(24, fontSize));
    this.updatePreference("fontSize", clampedSize);
    requiredElement<HTMLInputElement>("font-size").value = String(clampedSize);
    requiredElement("font-size-output").textContent = `${clampedSize}px`;
    for (const pane of this.panes.values()) {
      pane.setFontSize(clampedSize);
    }
  }

  private toggleGitPopover(): void {
    this.setGitPopover(this.gitPopover.hidden);
  }

  private setGitPopover(open: boolean): void {
    this.gitPopover.hidden = !open;
    this.gitPill.setAttribute("aria-expanded", String(open));
  }

  private toggleSidebar(): void {
    this.root.classList.toggle("sidebar-visible");
    setTimeout(() => this.activePane?.focus(), 180);
  }

  private openTerminalSearch(): void {
    this.terminalSearch.hidden = false;
    this.terminalSearchInput.focus();
    this.terminalSearchInput.select();
  }

  private closeTerminalSearch(): void {
    this.terminalSearch.hidden = true;
    this.activePane?.clearSearch();
  }

  private searchTerminal(): void {
    const query = this.terminalSearchInput.value;
    if (query && !this.activePane?.search(query)) {
      this.terminalSearchInput.classList.add("no-match");
    } else {
      this.terminalSearchInput.classList.remove("no-match");
    }
  }

  private handleShortcut(event: KeyboardEvent): void {
    if (this.tourActive) {
      if (event.ctrlKey || event.metaKey || event.altKey) {
        event.preventDefault();
      }
      return;
    }
    if (event.key === "Escape" && !this.gitPopover.hidden) {
      this.setGitPopover(false);
      return;
    }
    if (!event.ctrlKey || event.altKey) {
      return;
    }
    if (event.shiftKey && event.code === "KeyF") {
      event.preventDefault();
      this.openTerminalSearch();
    }
  }

  private handleAppCommand(command: AppCommand): void {
    if (this.tourActive) {
      return;
    }
    const handlers: Record<AppCommand, () => void> = {
      "new-tab": () => void this.createWorkspace(this.activePane?.cwd),
      "split-pane": () => void this.splitPane(),
      "close-pane": () => this.activePane && void this.closePane(this.activePane),
      "command-palette": () => this.openCommandPalette(),
      "toggle-sidebar": () => this.toggleSidebar(),
      "focus-command-bar": () => this.commandInput.focus(),
      "increase-font": () => this.updateFontSize(this.preferences.fontSize + 1),
      "decrease-font": () => this.updateFontSize(this.preferences.fontSize - 1),
      "reset-font": () => this.updateFontSize(defaultPreferences.fontSize)
    };
    handlers[command]();
  }

  private findWorkspace(pane: TerminalPane): Workspace | undefined {
    return this.workspaces.find((workspace) => workspace.panes.includes(pane));
  }

  private showToast(message: string, type: "info" | "error"): void {
    const toast = document.createElement("div");
    toast.className = `toast ${type}`;
    toast.textContent = message;
    requiredElement("toast-region").append(toast);
    setTimeout(() => toast.remove(), 5000);
  }

  private get activePane(): TerminalPane | null {
    return this.activeWorkspace?.activePane ?? null;
  }
}

function requiredElement<ElementType extends HTMLElement = HTMLElement>(id: string): ElementType {
  const element = document.getElementById(id);
  if (!element) {
    throw new Error(`Required element #${id} was not found`);
  }
  return element as ElementType;
}

function compactFolderName(path: string): string {
  if (path === "/") {
    return "/";
  }
  return path.split("/").filter(Boolean).at(-1) ?? "Terminal";
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  const units = ["KB", "MB", "GB", "TB"];
  let value = bytes / 1024;
  let unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  return `${value >= 10 ? value.toFixed(0) : value.toFixed(1)} ${units[unitIndex]}`;
}

function relativeTime(timestamp: number): string {
  const elapsedMinutes = Math.floor((Date.now() - timestamp) / 60_000);
  if (elapsedMinutes < 1) {
    return "now";
  }
  if (elapsedMinutes < 60) {
    return `${elapsedMinutes}m`;
  }
  const elapsedHours = Math.floor(elapsedMinutes / 60);
  if (elapsedHours < 24) {
    return `${elapsedHours}h`;
  }
  return `${Math.floor(elapsedHours / 24)}d`;
}

function escapeHtml(value: string): string {
  const element = document.createElement("span");
  element.textContent = value;
  return element.innerHTML;
}

function readJson<Value>(key: string, fallback: Value): Value {
  const value = localStorage.getItem(key);
  if (!value) {
    return fallback;
  }
  try {
    return JSON.parse(value) as Value;
  } catch {
    return fallback;
  }
}

function readStringArray(key: string, fallback: string[]): string[] {
  const value = readJson<unknown>(key, fallback);
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : fallback;
}

void new FriendlyTerminalApp().start();
