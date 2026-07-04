// Content script: paint page pink.
function buildPinkCss() {
  return [
    "html, body { background-color: #ffc0cb !important; }",
    "* { background-color: #ffd6e0 !important; color: #8b004f !important; border-color: #ff69b4 !important; }",
    "a { color: #c2185b !important; }",
  ].join("\n");
}

// Browser-only: inject style tag.
if (typeof document !== "undefined") {
  const style = document.createElement("style");
  style.textContent = buildPinkCss();
  (document.head || document.documentElement).appendChild(style);
}

// Node-only export for testing.
if (typeof module !== "undefined" && module.exports) {
  module.exports = { buildPinkCss };
}
