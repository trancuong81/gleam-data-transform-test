import { Ok, Error } from "../gleam.mjs";
import { toList } from "../gleam.mjs";
import fs from "node:fs";

export function read_file(path) {
  try {
    return new Ok(fs.readFileSync(path, "utf8"));
  } catch (e) {
    return new Error(e.message);
  }
}

export function get_args() {
  // process.argv: [node, script, ...args]
  return toList(process.argv.slice(2));
}

export function write_stdout(s) {
  process.stdout.write(s);
}
