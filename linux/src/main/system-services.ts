import { execFile } from "node:child_process";
import { open, readdir, stat } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
import { shell } from "electron";
import type { DirectoryListing, FileEntry, GitStatus } from "../shared/api";
import { requireAbsolutePath } from "./validation";

const executeFile = promisify(execFile);
const maximumDirectoryEntries = 1000;

export async function listDirectory(pathValue: unknown, showHidden: boolean): Promise<DirectoryListing> {
  const directoryPath = requireAbsolutePath(pathValue, "directory path");
  const directoryEntries = await readdir(directoryPath, { withFileTypes: true });
  const visibleEntries = directoryEntries
    .filter((entry) => showHidden || !entry.name.startsWith("."))
    .sort((left, right) => {
      if (left.isDirectory() !== right.isDirectory()) {
        return left.isDirectory() ? -1 : 1;
      }
      return left.name.localeCompare(right.name, undefined, { numeric: true, sensitivity: "base" });
    });
  const selectedEntries = visibleEntries.slice(0, maximumDirectoryEntries);
  const entries = await Promise.all(selectedEntries.map(async (entry): Promise<FileEntry> => {
    const entryPath = path.join(directoryPath, entry.name);
    let size = 0;
    let modifiedAt = 0;
    try {
      const metadata = await stat(entryPath);
      size = metadata.size;
      modifiedAt = metadata.mtimeMs;
    } catch {
      size = 0;
      modifiedAt = 0;
    }
    return {
      name: entry.name,
      path: entryPath,
      isDirectory: entry.isDirectory(),
      isHidden: entry.name.startsWith("."),
      size,
      modifiedAt
    };
  }));

  return {
    path: directoryPath,
    entries,
    truncated: visibleEntries.length > maximumDirectoryEntries
  };
}

async function hasExecutableMagic(targetPath: string): Promise<boolean> {
  const handle = await open(targetPath, "r");
  try {
    const buffer = Buffer.alloc(4);
    const { bytesRead } = await handle.read(buffer, 0, 4, 0);
    if (bytesRead >= 2 && buffer[0] === 0x23 && buffer[1] === 0x21) return true; // "#!"
    if (bytesRead >= 2 && buffer[0] === 0x4d && buffer[1] === 0x5a) return true; // "MZ"
    return bytesRead >= 4 && buffer.readUInt32BE(0) === 0x7f454c46; // ELF
  } finally {
    await handle.close();
  }
}

export async function openPath(pathValue: unknown): Promise<string> {
  const targetPath = requireAbsolutePath(pathValue, "path");
  try {
    const metadata = await stat(targetPath);
    // ponytail: exec bit alone false-positives on vfat/ntfs mounts, so also sniff magic bytes
    if (
      metadata.isFile() &&
      (targetPath.endsWith(".desktop") ||
        ((metadata.mode & 0o111) !== 0 && (await hasExecutableMagic(targetPath))))
    ) {
      shell.showItemInFolder(targetPath);
      return "";
    }
  } catch {
    // fall through; shell.openPath reports the error
  }
  return shell.openPath(targetPath);
}

export function revealPath(pathValue: unknown): void {
  shell.showItemInFolder(requireAbsolutePath(pathValue, "path"));
}

export async function queryGitStatus(pathValue: unknown): Promise<GitStatus | null> {
  const cwd = requireAbsolutePath(pathValue, "git path");
  try {
    const { stdout } = await executeFile("git", ["status", "--porcelain=v2", "--branch"], {
      cwd,
      timeout: 4000,
      maxBuffer: 1024 * 1024,
      encoding: "utf8"
    });
    const lines = stdout.split("\n");
    const branchLine = lines.find((line) => line.startsWith("# branch.head "));
    const aheadBehindLine = lines.find((line) => line.startsWith("# branch.ab "));
    if (!branchLine) {
      return null;
    }
    const branch = branchLine.slice("# branch.head ".length).trim();
    const aheadBehind = aheadBehindLine?.match(/\+(\d+)\s+-(\d+)/);
    return {
      branch: branch === "(detached)" ? "detached HEAD" : branch,
      changedFiles: lines.filter((line) => /^(1|2|u|\?)/.test(line)).length,
      ahead: Number.parseInt(aheadBehind?.[1] ?? "0", 10),
      behind: Number.parseInt(aheadBehind?.[2] ?? "0", 10)
    };
  } catch {
    return null;
  }
}
