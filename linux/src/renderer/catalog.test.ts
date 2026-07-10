import assert from "node:assert/strict";
import test from "node:test";
import { searchCommands } from "./catalog";

test("searches commands by plain-language intent", () => {
  const results = searchCommands("disk space");
  assert.ok(results.some((result) => result.command === "df -h"));
});

test("searches hidden keywords", () => {
  const results = searchCommands("undo add");
  assert.ok(results.some((result) => result.command === "git restore --staged file"));
});

test("returns the full catalog for a blank query", () => {
  assert.ok(searchCommands("  ").length >= 30);
});
