#!/usr/bin/env node
// Validate extension dir given as argv[2]: manifest parses, referenced files exist, JS parses.
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const dir = process.argv[2];
if (!dir) { console.error("usage: check.js <extension-dir>"); process.exit(2); }

try {
  const manifest = JSON.parse(fs.readFileSync(path.join(dir, "manifest.json"), "utf8"));
  const refs = [];
  for (const cs of manifest.content_scripts || []) {
    refs.push(...(cs.js || []), ...(cs.css || []));
  }
  for (const f of refs) {
    const p = path.join(dir, f);
    if (!fs.existsSync(p)) throw new Error("missing referenced file: " + f);
    if (f.endsWith(".js")) execFileSync("node", ["--check", p]);
  }
  console.log("OK: extension dir valid (" + refs.length + " referenced files)");
} catch (e) {
  console.error("FAIL: " + e.message);
  process.exit(1);
}
