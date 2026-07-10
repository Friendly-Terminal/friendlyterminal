import path from "node:path";

const maximumIpcTextLength = 1024 * 1024;
const maximumTerminalDimension = 1000;

export function requireText(value: unknown, name: string, maximumLength = maximumIpcTextLength): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maximumLength) {
    throw new Error(`${name} must be a non-empty string no longer than ${maximumLength} characters`);
  }
  return value;
}

export function requireAbsolutePath(value: unknown, name: string): string {
  const candidate = requireText(value, name, 32_768);
  if (!path.isAbsolute(candidate)) {
    throw new Error(`${name} must be an absolute path`);
  }
  return path.normalize(candidate);
}

export function requireTerminalDimension(value: unknown, name: string): number {
  if (!Number.isInteger(value) || (value as number) < 1 || (value as number) > maximumTerminalDimension) {
    throw new Error(`${name} must be an integer between 1 and ${maximumTerminalDimension}`);
  }
  return value as number;
}
