const assert = require("assert");
const m = JSON.parse(require("fs").readFileSync(__dirname + "/manifest.json", "utf8"));
assert.strictEqual(m.manifest_version, 3);
assert(m.content_scripts[0].matches.includes("<all_urls>"));
assert(m.content_scripts[0].js.includes("content.js"));
assert(m.name && m.version && m.description);
console.log("extension-manifest OK");
