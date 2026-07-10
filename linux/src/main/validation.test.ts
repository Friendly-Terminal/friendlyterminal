import assert from "node:assert/strict";
import test from "node:test";
import { requireAbsolutePath, requireTerminalDimension, requireText } from "./validation";

test("accepts safe terminal dimensions", () => {
  assert.equal(requireTerminalDimension(120, "columns"), 120);
});

test("rejects unsafe terminal dimensions", () => {
  assert.throws(() => requireTerminalDimension(0, "rows"));
  assert.throws(() => requireTerminalDimension(1001, "columns"));
  assert.throws(() => requireTerminalDimension(10.5, "columns"));
});

test("requires absolute normalized paths", () => {
  assert.equal(requireAbsolutePath("/tmp/example/../folder", "path"), "/tmp/folder");
  assert.throws(() => requireAbsolutePath("relative/path", "path"));
});

test("rejects empty and oversized IPC text", () => {
  assert.throws(() => requireText("", "input"));
  assert.throws(() => requireText("abcdef", "input", 5));
});
