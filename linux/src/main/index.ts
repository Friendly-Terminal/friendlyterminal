import path from "node:path";
import { app, BrowserWindow, ipcMain, Menu, nativeTheme, shell } from "electron";
import type { AppCommand, TerminalCreateRequest } from "../shared/api";
import { listDirectory, openPath, queryGitStatus, revealPath } from "./system-services";
import { TerminalManager } from "./terminal-manager";

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
        { label: "Toggle Sidebar", accelerator: "Ctrl+B", click: () => sendCommand("toggle-sidebar") },
        { label: "Command Palette", accelerator: "Ctrl+Shift+P", click: () => sendCommand("command-palette") },
        { label: "Focus Command Bar", accelerator: "Ctrl+K", click: () => sendCommand("focus-command-bar") },
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
        { role: "copy" },
        { role: "paste" },
        { role: "selectAll" }
      ]
    },
    {
      label: "Help",
      submenu: [
        { label: "Explore Commands", click: () => sendCommand("command-palette") },
        { label: "FriendlyTerminal on GitHub", click: () => void import("electron").then(({ shell }) => shell.openExternal("https://github.com/aaditaggarwal26/friendlyterminal")) }
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
      sandbox: false,
      devTools: !app.isPackaged
    }
  });
  window.loadFile(path.join(__dirname, "../renderer/index.html"));
  window.once("ready-to-show", () => window.show());
  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  window.webContents.on("will-navigate", (event) => event.preventDefault());
  window.webContents.on("destroyed", () => terminalManager?.closeOwner(window.webContents.id));
  return window;
}

app.whenReady().then(() => {
  terminalManager = new TerminalManager(shellResourcesPath(), path.join(app.getPath("userData"), "shell-integration"));
  registerIpc(terminalManager);
  Menu.setApplicationMenu(createMenu());
  mainWindow = createWindow();
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
