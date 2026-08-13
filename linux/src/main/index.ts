import path from "node:path";
import { app, BrowserWindow, clipboard, dialog, ipcMain, Menu, nativeTheme, Notification, shell } from "electron";
import type { AppCommand, TerminalCreateRequest } from "../shared/api";
import { listDirectory, openPath, queryGitStatus, revealPath } from "./system-services";
import { TerminalManager } from "./terminal-manager";

const repositoryUrl = "https://github.com/Friendly-Terminal/friendlyterminal";

let mainWindow: BrowserWindow | null = null;
let terminalManager: TerminalManager | null = null;

function shellResourcesPath(): string {
  return app.isPackaged
    ? path.join(process.resourcesPath, "shell")
    : path.join(app.getAppPath(), "resources", "shell");
}

function sendCommand(command: AppCommand): void {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send("app:command", command);
  }
}

function createMenu(): Menu {
  return Menu.buildFromTemplate([
    {
      label: "File",
      submenu: [
        { label: "New Tab", accelerator: "Ctrl+Shift+T", click: () => sendCommand("new-tab") },
        { label: "Split Pane", accelerator: "Ctrl+Shift+D", click: () => sendCommand("split-pane") },
        { type: "separator" },
        { label: "Close Pane", accelerator: "Ctrl+Shift+W", click: () => sendCommand("close-pane") },
        { type: "separator" },
        { role: "quit" }
      ]
    },
    {
      label: "View",
      submenu: [
        { label: "Toggle Sidebar", accelerator: "Ctrl+Shift+B", click: () => sendCommand("toggle-sidebar") },
        { label: "Command Palette", accelerator: "Ctrl+Shift+P", click: () => sendCommand("command-palette") },
        { label: "Focus Command Bar", accelerator: "Ctrl+Shift+K", click: () => sendCommand("focus-command-bar") },
        { type: "separator" },
        { label: "Increase Font Size", accelerator: "Ctrl+=", click: () => sendCommand("increase-font") },
        { label: "Decrease Font Size", accelerator: "Ctrl+-", click: () => sendCommand("decrease-font") },
        { label: "Reset Font Size", accelerator: "Ctrl+0", click: () => sendCommand("reset-font") },
        { type: "separator" },
        { role: "togglefullscreen" }
      ]
    },
    {
      label: "Edit",
      submenu: [
        { role: "copy", registerAccelerator: false },
        { role: "paste", registerAccelerator: false },
        { role: "selectAll", registerAccelerator: false }
      ]
    },
    {
      label: "Help",
      submenu: [
        { label: "Explore Commands", click: () => sendCommand("command-palette") },
        { label: "FriendlyTerminal on GitHub", click: () => void shell.openExternal(repositoryUrl) },
        { label: "Check for Updates…", click: () => void checkForUpdates() }
      ]
    }
  ]);
}

function registerIpc(manager: TerminalManager): void {
  ipcMain.handle("terminal:create", (event, request: TerminalCreateRequest) => manager.create(event.sender, request));
  ipcMain.on("terminal:ready", (event, id: unknown) => safelyHandle(() => manager.ready(event.sender.id, id)));
  ipcMain.on("terminal:write", (event, id: unknown, data: unknown) => safelyHandle(() => manager.write(event.sender.id, id, data)));
  ipcMain.on("terminal:resize", (event, id: unknown, columns: unknown, rows: unknown) => safelyHandle(() => manager.resize(event.sender.id, id, columns, rows)));
  ipcMain.handle("terminal:close", (event, id: unknown) => manager.close(event.sender.id, id));
  ipcMain.handle("files:list", (_event, pathValue: unknown, showHidden: unknown) => listDirectory(pathValue, showHidden === true));
  ipcMain.handle("files:open", (_event, pathValue: unknown) => openPath(pathValue));
  ipcMain.on("files:reveal", (_event, pathValue: unknown) => safelyHandle(() => revealPath(pathValue)));
  ipcMain.handle("git:status", (_event, pathValue: unknown) => queryGitStatus(pathValue));
  ipcMain.handle("app:version", () => app.getVersion());
  ipcMain.on("clipboard-write-selection", (_event, text: unknown) => {
    if (typeof text === "string" && text.length > 0 && text.length <= 1024 * 1024) {
      clipboard.writeText(text, "selection");
    }
  });
  ipcMain.handle("app:open-external", async (_event, urlValue: unknown) => {
    if (typeof urlValue !== "string" || urlValue.length > 2048) {
      throw new Error("External URL is invalid");
    }
    const url = new URL(urlValue);
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      throw new Error("Only HTTP and HTTPS links can be opened");
    }
    await shell.openExternal(url.toString());
  });
}

function safelyHandle(action: () => void): void {
  try {
    action();
  } catch {
    return;
  }
}

async function fetchLatestVersion(): Promise<string | null> {
  try {
    const response = await fetch("https://api.github.com/repos/Friendly-Terminal/friendlyterminal/releases/latest", {
      headers: { Accept: "application/vnd.github+json" },
      signal: AbortSignal.timeout(10000)
    });
    if (!response.ok) {
      return null;
    }
    const body = (await response.json()) as { tag_name?: unknown };
    return typeof body.tag_name === "string" ? body.tag_name.replace(/^v/, "") : null;
  } catch {
    return null;
  }
}

function isNewerVersion(latest: string, current: string): boolean {
  const latestParts = latest.split(".").map((part) => Number.parseInt(part, 10));
  const currentParts = current.split(".").map((part) => Number.parseInt(part, 10));
  for (let index = 0; index < 3; index += 1) {
    const latestPart = latestParts[index] ?? 0;
    const currentPart = currentParts[index] ?? 0;
    if (Number.isNaN(latestPart) || Number.isNaN(currentPart)) {
      return false;
    }
    if (latestPart !== currentPart) {
      return latestPart > currentPart;
    }
  }
  return false;
}

async function checkForUpdates(): Promise<void> {
  const latest = await fetchLatestVersion();
  if (latest === null) {
    await dialog.showMessageBox({
      type: "warning",
      message: "Could not check for updates",
      detail: "Check your network connection and try again."
    });
    return;
  }
  if (isNewerVersion(latest, app.getVersion())) {
    const { response } = await dialog.showMessageBox({
      type: "info",
      message: `FriendlyTerminal ${latest} is available`,
      detail: `You are running ${app.getVersion()}.`,
      buttons: ["View Releases", "Later"],
      defaultId: 0,
      cancelId: 1
    });
    if (response === 0) {
      await shell.openExternal(`${repositoryUrl}/releases`);
    }
    return;
  }
  await dialog.showMessageBox({
    type: "info",
    message: "You're up to date",
    detail: `FriendlyTerminal ${app.getVersion()} is the latest version.`
  });
}

function checkForUpdatesAtStartup(): void {
  void fetchLatestVersion().then((latest) => {
    if (latest !== null && isNewerVersion(latest, app.getVersion()) && Notification.isSupported()) {
      new Notification({
        title: "FriendlyTerminal update available",
        body: `Version ${latest} is available. See Help → Check for Updates…`
      }).show();
    }
  });
}

function createWindow(): BrowserWindow {
  const window = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 760,
    minHeight: 520,
    backgroundColor: nativeTheme.shouldUseDarkColors ? "#101112" : "#f4f1ea",
    show: false,
    title: "FriendlyTerminal",
    webPreferences: {
      preload: path.join(__dirname, "../preload/index.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      devTools: !app.isPackaged
    }
  });
  window.loadFile(path.join(__dirname, "../renderer/index.html"));
  window.once("ready-to-show", () => window.show());
  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  window.webContents.on("will-navigate", (event) => event.preventDefault());
  const webContentsId = window.webContents.id;
  window.webContents.on("destroyed", () => terminalManager?.closeOwner(webContentsId));
  return window;
}

app.whenReady().then(() => {
  terminalManager = new TerminalManager(shellResourcesPath(), path.join(app.getPath("userData"), "shell-integration"));
  registerIpc(terminalManager);
  Menu.setApplicationMenu(createMenu());
  mainWindow = createWindow();
  checkForUpdatesAtStartup();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      mainWindow = createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("before-quit", () => terminalManager?.closeAll());
