export interface TerminalCreateRequest {
  cwd?: string;
  columns: number;
  rows: number;
}

export interface TerminalCreated {
  id: string;
  shell: string;
  cwd: string;
}

export interface TerminalDataEvent {
  id: string;
  data: string;
}

export interface TerminalExitEvent {
  id: string;
  exitCode: number;
  signal?: number;
}

export interface FileEntry {
  name: string;
  path: string;
  isDirectory: boolean;
  isHidden: boolean;
  size: number;
  modifiedAt: number;
}

export interface DirectoryListing {
  path: string;
  entries: FileEntry[];
  truncated: boolean;
}

export interface GitStatus {
  branch: string;
  changedFiles: number;
  ahead: number;
  behind: number;
}

export type AppCommand =
  | "new-tab"
  | "split-pane"
  | "close-pane"
  | "command-palette"
  | "toggle-sidebar"
  | "focus-command-bar"
  | "increase-font"
  | "decrease-font"
  | "reset-font";

export interface FriendlyTerminalApi {
  terminal: {
    create(request: TerminalCreateRequest): Promise<TerminalCreated>;
    ready(id: string): void;
    write(id: string, data: string): void;
    resize(id: string, columns: number, rows: number): void;
    close(id: string): Promise<void>;
    onData(listener: (event: TerminalDataEvent) => void): () => void;
    onExit(listener: (event: TerminalExitEvent) => void): () => void;
  };
  files: {
    list(path: string, showHidden: boolean): Promise<DirectoryListing>;
    open(path: string): Promise<string>;
    reveal(path: string): void;
  };
  git: {
    status(path: string): Promise<GitStatus | null>;
  };
  app: {
    version(): Promise<string>;
    openExternal(url: string): Promise<void>;
    onCommand(listener: (command: AppCommand) => void): () => void;
  };
}

declare global {
  interface Window {
    friendlyTerminal: FriendlyTerminalApi;
  }
}
