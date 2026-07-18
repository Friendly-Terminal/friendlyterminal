import assert from "node:assert/strict";
import test from "node:test";
import {
  searchCommands,
  searchHelpCatalog,
  helpCategories,
  defaultEnabledHelpCategoryIds
} from "./catalog";

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

test("exposes the 22 canonical help categories in order", () => {
  const ids = helpCategories.map((category) => category.id);
  assert.deepEqual(ids, [
    "Navigate", "Files", "GitHub", "AI", "Search", "System", "Network", "Permissions",
    "Processes", "Archives", "Text", "Editors", "npm", "pip", "Python", "Node",
    "Packages", "Docker", "Environment", "Remote", "Disk", "Misc"
  ]);
});

test("each category id equals its name and carries an icon and commands", () => {
  for (const category of helpCategories) {
    assert.equal(category.id, category.name);
    assert.ok(category.icon.length > 0, `${category.id} is missing an icon`);
    assert.ok(category.commands.length > 0, `${category.id} has no commands`);
  }
});

test("default-enabled set matches the cross-platform nine and resolves to real ids", () => {
  assert.deepEqual(defaultEnabledHelpCategoryIds, [
    "Navigate", "Files", "GitHub", "AI", "Search", "System", "Network", "npm", "pip"
  ]);
  for (const id of defaultEnabledHelpCategoryIds) {
    assert.ok(helpCategories.some((category) => category.id === id), `default id ${id} has no category`);
  }
});

test("Packages replaces Homebrew: apt-flavored and discoverable across distros", () => {
  const packages = helpCategories.find((category) => category.id === "Packages");
  assert.ok(packages, "Packages category should exist");
  assert.ok(packages.commands.some((item) => item.command.startsWith("sudo apt install")));
  assert.ok(
    packages.commands.some((item) => {
      const keywords = item.keywords ?? "";
      return keywords.includes("dnf") && keywords.includes("pacman");
    }),
    "at least one Packages entry should mention dnf and pacman for search discoverability"
  );
});

test("help search spans every category regardless of enablement", () => {
  assert.ok(!defaultEnabledHelpCategoryIds.includes("Docker"));
  const hits = searchHelpCatalog("docker");
  assert.ok(hits.length > 0);
  assert.ok(hits.some((hit) => hit.category.id === "Docker"));
});

test("help search matches on category name, command, detail, and keywords", () => {
  assert.ok(searchHelpCatalog("Network").some((hit) => hit.category.id === "Network"));
  assert.ok(searchHelpCatalog("lsblk").some((hit) => hit.item.command === "lsblk"));
  assert.ok(searchHelpCatalog("wayland").some((hit) => hit.item.command.startsWith("xclip")));
});

test("help search returns nothing for a blank query", () => {
  assert.equal(searchHelpCatalog("   ").length, 0);
});

test("dangerous commands are flagged so they can be styled carefully", () => {
  const hits = searchHelpCatalog("rm -rf");
  assert.ok(hits.some((hit) => hit.item.dangerous === true));
});
