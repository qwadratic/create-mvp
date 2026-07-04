const assert = require("assert");
const { buildPinkCss } = require("./content.js");

const css = buildPinkCss();
assert(typeof css === "string" && css.length > 0, "css string");
assert(css.includes("html, body"), "html/body selector");
assert(css.includes("*"), "universal selector");
assert(css.includes("background-color: #ffc0cb !important"), "pink bg !important");
assert(css.includes("color: #8b004f !important"), "dark pink text !important");
assert((css.match(/!important/g) || []).length >= 4, "important rules count");
console.log("pink-css-injector: OK");
