import { contextBridge, ipcRenderer } from "electron";
import type { AppCommand, FriendlyTerminalApi, TerminalDataEvent, TerminalExitEvent } from "../shared/api";

const api: FriendlyTerminalApi = {
  terminal: {
    create: (request) => ipcRenderer.invoke("terminal:create", request),
    ready: (id) => ipcRenderer.send("terminal:ready", id),
    write: (id, data) => ipcRenderer.send("terminal:write", id, data),
    resize: (id, columns, rows) => ipcRenderer.send("terminal:resize", id, columns, rows),
    close: (id) => ipcRenderer.invoke("terminal:close", id),
    onData: (listener) => {
      const handler = (_event: Electron.IpcRendererEvent, payload: TerminalDataEvent): void => listener(payload);
      ipcRenderer.on("terminal:data", handler);
      return () => ipcRenderer.removeListener("terminal:data", handler);
    },
    onExit: (listener) => {
      const handler = (_event: Electron.IpcRendererEvent, payload: TerminalExitEvent): void => listener(payload);
      ipcRenderer.on("terminal:exit", handler);
      return () => ipcRenderer.removeListener("terminal:exit", handler);
    }
  },
  files: {
    list: (path, showHidden) => ipcRenderer.invoke("files:list", path, showHidden),
    open: (path) => ipcRenderer.invoke("files:open", path),
    reveal: (path) => ipcRenderer.send("files:reveal", path)
  },
  git: {
    status: (path) => ipcRenderer.invoke("git:status", path)
  },
  app: {
    version: () => ipcRenderer.invoke("app:version"),
    openExternal: (url) => ipcRenderer.invoke("app:open-external", url),
    onCommand: (listener) => {
      const handler = (_event: Electron.IpcRendererEvent, command: AppCommand): void => listener(command);
      ipcRenderer.on("app:command", handler);
      return () => ipcRenderer.removeListener("app:command", handler);
    }
  }
};

contextBridge.exposeInMainWorld("friendlyTerminal", api);
