import "@xterm/xterm/css/xterm.css";
import type { AppCommand, DirectoryListing, FileEntry, GitStatus, TerminalDataEvent, TerminalExitEvent } from "../shared/api";
import { searchCommands } from "./catalog";
import type { CommandDefinition } from "./catalog";
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

class FriendlyTerminalApp {
  private readonly panes = new Map<string, TerminalPane>();
  private readonly workspaces: Workspace[] = [];
  private readonly history: HistoryEntry[];
  private preferences: Preferences;
  private activeWorkspace: Workspace | null = null;
  private readonly pendingCommands = new Map<string, HistoryEntry>();
  private refreshSequence = 0;

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
  private readonly helpResults = requiredElement<HTMLElement>("help-results");
  private readonly commandInput = requiredElement<HTMLInputElement>("command-input");
  private readonly commandDialog = requiredElement<HTMLDialogElement>("command-dialog");
  private readonly commandSearch = requiredElement<HTMLInputElement>("command-search");
  private readonly commandResults = requiredElement<HTMLElement>("command-results");
  private readonly settingsDialog = requiredElement<HTMLDialogElement>("settings-dialog");
  private readonly welcomeDialog = requiredElement<HTMLDialogElement>("welcome-dialog");
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
    this.renderHelp("");
    await this.createWorkspace();
    requiredElement("loading").remove();
    if (localStorage.getItem("friendlyterminal.welcomed") !== "true") {
      this.welcomeDialog.showModal();
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
    requiredElement("welcome-start").addEventListener("click", () => {
      localStorage.setItem("friendlyterminal.welcomed", "true");
      this.welcomeDialog.close();
      this.activePane?.focus();
    });
    this.commandInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        this.runCommandBar();
      } else if (event.key === "Escape") {
        this.commandInput.value = "";
        this.activePane?.focus();
      }
    });
    this.commandSearch.addEventListener("input", () => this.renderCommandResults(this.commandSearch.value));
    this.helpSearch.addEventListener("input", () => this.renderHelp(this.helpSearch.value));
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

  private renderHelp(query: string): void {
    const matches = searchCommands(query);
    if (matches.length === 0) {
      this.helpResults.replaceChildren();
      this.helpResults.innerHTML = `<div class="empty-state">No commands match. Try describing the outcome in different words.</div>`;
      return;
    }
    this.renderCommandGroups(matches, this.helpResults);
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

void new FriendlyTerminalApp().start();
