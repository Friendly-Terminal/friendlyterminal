import { rm } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");

await Promise.all([
  rm(path.join(root, "dist"), { force: true, recursive: true }),
  rm(path.join(root, "release"), { force: true, recursive: true })
]);
