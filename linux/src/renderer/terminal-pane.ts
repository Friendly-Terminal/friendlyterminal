import { FitAddon } from "@xterm/addon-fit";
import { SearchAddon } from "@xterm/addon-search";
import { WebLinksAddon } from "@xterm/addon-web-links";
import { Terminal } from "@xterm/xterm";
import type { IDisposable, ITheme } from "@xterm/xterm";
import type { TerminalCreated, TerminalExitEvent } from "../shared/api";

export interface TerminalPaneEvents {
  onActivate(pane: TerminalPane): void;
  onClose(pane: TerminalPane): void;
  onCwdChange(pane: TerminalPane, cwd: string): void;
  onCommand(pane: TerminalPane, command: string): void;
  onCommandEnd(pane: TerminalPane, exitCode: number): void;
}

const darkTheme: ITheme = {
  background: "#101112",
  foreground: "#e8e5dd",
  cursor: "#f5b544",
  cursorAccent: "#101112",
  selectionBackground: "#3d4f5f",
  black: "#171819",
  red: "#f07178",
  green: "#aad94c",
  yellow: "#ffb454",
  blue: "#59c2ff",
  magenta: "#d2a6ff",
  cyan: "#95e6cb",
  white: "#e6e1cf",
  brightBlack: "#5c6773",
  brightRed: "#f07178",
  brightGreen: "#aad94c",
  brightYellow: "#ffd580",
  brightBlue: "#73d0ff",
  brightMagenta: "#dfbfff",
  brightCyan: "#95e6cb",
  brightWhite: "#f8f6f0"
};

export class TerminalPane {
  readonly root: HTMLElement;
  readonly id: string;
  readonly shell: string;
  cwd: string;
  private readonly terminal: Terminal;
  private readonly fitAddon = new FitAddon();
  private readonly searchAddon = new SearchAddon();
  private readonly subscriptions: IDisposable[] = [];
  private readonly statusElement: HTMLElement;
  private readonly pathElement: HTMLElement;
  private readonly terminalHost: HTMLElement;
  private resizeObserver: ResizeObserver | null = null;
  private disposed = false;

  private constructor(created: TerminalCreated, fontSize: number, private readonly events: TerminalPaneEvents) {
    this.id = created.id;
    this.shell = created.shell;
    this.cwd = created.cwd;
    this.root = document.createElement("section");
    this.root.className = "terminal-pane";
    this.root.dataset.paneId = this.id;
    this.root.innerHTML = `
      <header class="pane-header">
        <div class="pane-identity"><span class="status-dot" aria-hidden="true"></span><span class="pane-shell"></span></div>
        <div class="pane-path"></div>
        <button class="icon-button pane-close" type="button" aria-label="Close pane">×</button>
      </header>
      <div class="terminal-host"></div>
    `;
    this.statusElement = this.requireElement(".status-dot");
    this.pathElement = this.requireElement(".pane-path");
    this.terminalHost = this.requireElement(".terminal-host");
    this.requireElement(".pane-shell").textContent = created.shell;
    this.pathElement.textContent = this.compactPath(this.cwd);
    this.terminal = new Terminal({
      allowProposedApi: false,
      convertEol: false,
      cursorBlink: true,
      cursorStyle: "bar",
      cursorWidth: 2,
      fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
      fontSize,
      lineHeight: 1.22,
      letterSpacing: 0,
      minimumContrastRatio: 4.5,
      scrollback: 20_000,
      theme: darkTheme
    });
    this.terminal.loadAddon(this.fitAddon);
    this.terminal.loadAddon(this.searchAddon);
    this.terminal.loadAddon(new WebLinksAddon((_event, uri) => void window.friendlyTerminal.app.openExternal(uri)));
    this.registerShellMarkers();
    this.registerInteractions();
  }

  static async create(cwd: string | undefined, fontSize: number, events: TerminalPaneEvents): Promise<TerminalPane> {
    const request = cwd === undefined ? { columns: 80, rows: 24 } : { cwd, columns: 80, rows: 24 };
    const created = await window.friendlyTerminal.terminal.create(request);
    return new TerminalPane(created, fontSize, events);
  }

  mount(container: HTMLElement): void {
    container.append(this.root);
    this.terminal.open(this.terminalHost);
    this.resizeObserver = new ResizeObserver(() => this.fit());
    this.resizeObserver.observe(this.terminalHost);
    this.fit();
    this.terminal.focus();
    window.friendlyTerminal.terminal.ready(this.id);
  }

  receiveData(data: string): void {
    if (!this.disposed) {
      this.terminal.write(data);
    }
  }

  receiveExit(event: TerminalExitEvent): void {
    if (this.disposed) {
      return;
    }
    this.statusElement.classList.add("exited");
    this.root.classList.add("pane-exited");
    this.terminal.writeln(`\r\n\x1b[38;2;245;181;68mShell exited with status ${event.exitCode}. Close this pane or open a new tab.\x1b[0m`);
  }

  activate(): void {
    this.root.classList.add("active");
    this.terminal.focus();
  }

  deactivate(): void {
    this.root.classList.remove("active");
  }

  focus(): void {
    this.terminal.focus();
  }

  run(command: string): void {
    window.friendlyTerminal.terminal.write(this.id, `${command}\r`);
  }

  send(data: string): void {
    window.friendlyTerminal.terminal.write(this.id, data);
  }

  navigate(path: string): void {
    this.run(`cd -- ${quoteShell(path)}`);
  }

  setFontSize(fontSize: number): void {
    this.terminal.options.fontSize = fontSize;
    this.fit();
  }

  search(query: string): boolean {
    return this.searchAddon.findNext(query, { incremental: true, caseSensitive: false });
  }

  clearSearch(): void {
    this.searchAddon.clearDecorations();
    this.focus();
  }

  async dispose(): Promise<void> {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    this.resizeObserver?.disconnect();
    for (const subscription of this.subscriptions) {
      subscription.dispose();
    }
    this.terminal.dispose();
    this.root.remove();
    await window.friendlyTerminal.terminal.close(this.id).catch(() => undefined);
  }

  private registerInteractions(): void {
    this.subscriptions.push(this.terminal.onData((data) => window.friendlyTerminal.terminal.write(this.id, data)));
    this.subscriptions.push(this.terminal.onResize(({ cols, rows }) => window.friendlyTerminal.terminal.resize(this.id, cols, rows)));
    this.subscriptions.push(this.terminal.onSelectionChange(() => {
      const selection = this.terminal.getSelection();
      if (selection.length > 0) {
        void navigator.clipboard.writeText(selection);
      }
    }));
    this.terminal.attachCustomKeyEventHandler((event) => {
      if (event.type !== "keydown") {
        return true;
      }
      if (event.ctrlKey && event.shiftKey && event.code === "KeyC") {
        const selection = this.terminal.getSelection();
        if (selection) {
          void navigator.clipboard.writeText(selection);
        }
        return false;
      }
      if (event.ctrlKey && event.shiftKey && event.code === "KeyV") {
        void navigator.clipboard.readText().then((text) => this.terminal.paste(text));
        return false;
      }
      return true;
    });
    this.root.addEventListener("pointerdown", () => this.events.onActivate(this));
    this.root.querySelector(".pane-close")?.addEventListener("click", () => this.events.onClose(this));
  }

  private registerShellMarkers(): void {
    this.terminal.parser.registerOscHandler(7, (data) => {
      const nextPath = parseFileUri(data);
      if (nextPath) {
        this.cwd = nextPath;
        this.pathElement.textContent = this.compactPath(nextPath);
        this.events.onCwdChange(this, nextPath);
      }
      return true;
    });
    this.terminal.parser.registerOscHandler(633, (data) => {
      if (data.startsWith("E;")) {
        const command = decodeBase64(data.slice(2));
        if (command) {
          this.events.onCommand(this, command);
        }
      }
      return true;
    });
    this.terminal.parser.registerOscHandler(133, (data) => {
      if (data.startsWith("D")) {
        const exitCode = Number.parseInt(data.split(";")[1] ?? "0", 10);
        this.events.onCommandEnd(this, Number.isNaN(exitCode) ? 0 : exitCode);
      }
      return true;
    });
  }

  private fit(): void {
    if (!this.disposed && this.terminalHost.clientWidth > 0 && this.terminalHost.clientHeight > 0) {
      this.fitAddon.fit();
    }
  }

  private compactPath(pathValue: string): string {
    const home = document.documentElement.dataset.home;
    return home && pathValue.startsWith(home) ? `~${pathValue.slice(home.length)}` : pathValue;
  }

  private requireElement(selector: string): HTMLElement {
    const element = this.root.querySelector<HTMLElement>(selector);
    if (!element) {
      throw new Error(`Terminal pane element ${selector} was not found`);
    }
    return element;
  }
}

export function quoteShell(value: string): string {
  return `'${value.replaceAll("'", `'\\''`)}'`;
}

function parseFileUri(value: string): string | null {
  try {
    const uri = new URL(value);
    return uri.protocol === "file:" ? decodeURIComponent(uri.pathname) : null;
  } catch {
    return null;
  }
}

function decodeBase64(value: string): string | null {
  try {
    const bytes = Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
    return new TextDecoder().decode(bytes).trim();
  } catch {
    return null;
  }
}
