import { randomUUID } from "node:crypto";
import { accessSync, chmodSync, constants, copyFileSync, existsSync, mkdirSync, statSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import type { WebContents } from "electron";
import type { IPty } from "node-pty";
import * as pty from "node-pty";
import type { TerminalCreateRequest, TerminalCreated, TerminalExitEvent } from "../shared/api";
import { requireAbsolutePath, requireTerminalDimension, requireText } from "./validation";

interface ManagedTerminal {
  process: IPty;
  ownerId: number;
  owner: WebContents;
  bufferedData: string[];
  isReady: boolean;
}

interface ShellLaunch {
  executable: string;
  args: string[];
  environment: Record<string, string>;
}

export class TerminalManager {
  private readonly terminals = new Map<string, ManagedTerminal>();
  private readonly zshIntegrationPath: string;

  constructor(private readonly shellResourcesPath: string, shellRuntimePath: string) {
    this.zshIntegrationPath = this.prepareZshIntegration(shellRuntimePath);
  }

  create(owner: WebContents, request: TerminalCreateRequest): TerminalCreated {
    const columns = requireTerminalDimension(request.columns, "columns");
    const rows = requireTerminalDimension(request.rows, "rows");
    const cwd = this.resolveWorkingDirectory(request.cwd);
    const shell = this.resolveShell();
    const launch = this.createShellLaunch(shell);
    const id = randomUUID();
    const environment = this.createEnvironment(launch.environment);
    const terminalProcess = pty.spawn(launch.executable, launch.args, {
      name: "xterm-256color",
      cols: columns,
      rows,
      cwd,
      env: environment,
      encoding: "utf8"
    });

    this.terminals.set(id, { process: terminalProcess, ownerId: owner.id, owner, bufferedData: [], isReady: false });
    terminalProcess.onData((data) => {
      const managedTerminal = this.terminals.get(id);
      if (!managedTerminal) {
        return;
      }
      if (managedTerminal.isReady && !owner.isDestroyed()) {
        owner.send("terminal:data", { id, data });
      } else if (managedTerminal.bufferedData.join("").length < 1024 * 1024) {
        managedTerminal.bufferedData.push(data);
      }
    });
    terminalProcess.onExit(({ exitCode, signal }) => {
      this.terminals.delete(id);
      if (!owner.isDestroyed()) {
        const event: TerminalExitEvent = { id, exitCode };
        if (signal !== undefined) {
          event.signal = signal;
        }
        owner.send("terminal:exit", event);
      }
    });

    return { id, shell: path.basename(shell), cwd };
  }

  ready(ownerId: number, idValue: unknown): void {
    const id = requireText(idValue, "terminal id", 128);
    const terminal = this.getOwnedTerminal(ownerId, id);
    terminal.isReady = true;
    const data = terminal.bufferedData.join("");
    terminal.bufferedData = [];
    if (data.length > 0 && !terminal.owner.isDestroyed()) {
      terminal.owner.send("terminal:data", { id, data });
    }
  }

  write(ownerId: number, idValue: unknown, dataValue: unknown): void {
    const id = requireText(idValue, "terminal id", 128);
    const data = requireText(dataValue, "terminal input");
    this.getOwnedTerminal(ownerId, id).process.write(data);
  }

  resize(ownerId: number, idValue: unknown, columnsValue: unknown, rowsValue: unknown): void {
    const id = requireText(idValue, "terminal id", 128);
    const columns = requireTerminalDimension(columnsValue, "columns");
    const rows = requireTerminalDimension(rowsValue, "rows");
    this.getOwnedTerminal(ownerId, id).process.resize(columns, rows);
  }

  close(ownerId: number, idValue: unknown): void {
    const id = requireText(idValue, "terminal id", 128);
    const terminal = this.getOwnedTerminal(ownerId, id);
    this.terminals.delete(id);
    terminal.process.kill();
  }

  closeOwner(ownerId: number): void {
    for (const [id, terminal] of this.terminals) {
      if (terminal.ownerId === ownerId) {
        this.terminals.delete(id);
        terminal.process.kill();
      }
    }
  }

  closeAll(): void {
    for (const terminal of this.terminals.values()) {
      terminal.process.kill();
    }
    this.terminals.clear();
  }

  private getOwnedTerminal(ownerId: number, id: string): ManagedTerminal {
    const terminal = this.terminals.get(id);
    if (!terminal || terminal.ownerId !== ownerId) {
      throw new Error("Terminal session was not found");
    }
    return terminal;
  }

  private resolveWorkingDirectory(requestedPath: string | undefined): string {
    const candidate = requestedPath === undefined ? os.homedir() : requireAbsolutePath(requestedPath, "cwd");
    try {
      if (statSync(candidate).isDirectory()) {
        return candidate;
      }
    } catch {
      return os.homedir();
    }
    return os.homedir();
  }

  private resolveShell(): string {
    const candidates = [process.env.SHELL, "/bin/bash", "/bin/zsh", "/usr/bin/fish", "/bin/sh"];
    for (const candidate of candidates) {
      if (!candidate || !path.isAbsolute(candidate)) {
        continue;
      }
      try {
        accessSync(candidate, constants.X_OK);
        return candidate;
      } catch {
        continue;
      }
    }
    throw new Error("No supported interactive shell could be found");
  }

  private createShellLaunch(executable: string): ShellLaunch {
    const shellName = path.basename(executable);
    if (shellName === "zsh" && existsSync(path.join(this.zshIntegrationPath, ".zshrc"))) {
      const userZdotdir = process.env.ZDOTDIR ?? os.homedir();
      return {
        executable,
        args: ["-l", "-i"],
        environment: {
          FRIENDLY_TERMINAL_USER_ZDOTDIR: userZdotdir,
          HISTFILE: process.env.HISTFILE ?? path.join(userZdotdir, ".zsh_history"),
          ZDOTDIR: this.zshIntegrationPath
        }
      };
    }
    if (shellName === "bash" && existsSync(path.join(this.shellResourcesPath, "bash-integration.bash"))) {
      return {
        executable,
        args: ["--noprofile", "--rcfile", path.join(this.shellResourcesPath, "bash-integration.bash"), "-i"],
        environment: {}
      };
    }
    return { executable, args: ["-l", "-i"], environment: {} };
  }

  private createEnvironment(overrides: Record<string, string>): Record<string, string> {
    const environment: Record<string, string> = {};
    for (const [key, value] of Object.entries(process.env)) {
      if (value !== undefined) {
        environment[key] = value;
      }
    }
    return {
      ...environment,
      ...overrides,
      TERM: "xterm-256color",
      COLORTERM: "truecolor",
      TERMINAL_EMULATOR: "FriendlyTerminal",
      FRIENDLY_TERMINAL: "1"
    };
  }

  private prepareZshIntegration(shellRuntimePath: string): string {
    const destination = path.join(shellRuntimePath, "zsh");
    const source = path.join(this.shellResourcesPath, "zsh");
    mkdirSync(destination, { recursive: true, mode: 0o700 });
    for (const fileName of [".zprofile", ".zshrc", ".zlogin"]) {
      copyFileSync(path.join(source, fileName), path.join(destination, fileName));
      chmodSync(path.join(destination, fileName), 0o600);
    }
    return destination;
  }
}
