import { copyFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { build } from "esbuild";

const root = path.resolve(import.meta.dirname, "..");
const dist = path.join(root, "dist");

await Promise.all([
  build({
    entryPoints: [path.join(root, "src/main/index.ts")],
    outfile: path.join(dist, "main/index.js"),
    bundle: true,
    platform: "node",
    format: "cjs",
    target: "node22",
    external: ["electron", "node-pty"],
    sourcemap: true
  }),
  build({
    entryPoints: [path.join(root, "src/preload/index.ts")],
    outfile: path.join(dist, "preload/index.js"),
    bundle: true,
    platform: "node",
    format: "cjs",
    target: "node22",
    external: ["electron"],
    sourcemap: true
  }),
  build({
    entryPoints: [path.join(root, "src/renderer/app.ts")],
    outfile: path.join(dist, "renderer/app.js"),
    bundle: true,
    platform: "browser",
    format: "iife",
    target: "chrome136",
    sourcemap: true
  })
]);

await mkdir(path.join(dist, "renderer"), { recursive: true });
await Promise.all([
  copyFile(path.join(root, "src/renderer/index.html"), path.join(dist, "renderer/index.html")),
  copyFile(path.join(root, "src/renderer/styles.css"), path.join(dist, "renderer/styles.css"))
]);
