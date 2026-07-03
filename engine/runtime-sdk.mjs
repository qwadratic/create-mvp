#!/usr/bin/env node
// pi agentic-loop SDK runtime — same contract as cli mode:
// prompt on stdin, tools run in cwd, assistant text on stdout, nonzero exit on failure.
// Env (set by engine/agent):
//   ENGINE_NO_TOOLS=1                 plan role: no tools
//   ENGINE_MODEL=provider/id          effort knob (optional)
//   ENGINE_THINKING=off|minimal|low|medium|high|xhigh (optional)
import { execSync } from "node:child_process";
import { readFileSync, realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

async function loadSdk() {
  try {
    return await import("@earendil-works/pi-coding-agent");
  } catch {
    // ponytail: global npm install invisible to ESM resolution — locate package
    // via the pi binary symlink. Ceiling: local node_modules dep; upgrade: npm i.
    const bin = realpathSync(execSync("command -v pi", { encoding: "utf8" }).trim()); // .../dist/cli.js
    return import(pathToFileURL(join(dirname(bin), "index.js")).href);
  }
}

const {
  AuthStorage,
  createAgentSession,
  DefaultResourceLoader,
  getAgentDir,
  ModelRegistry,
  SessionManager,
} = await loadSdk();

const prompt = readFileSync(0, "utf8").trim();
if (!prompt) {
  console.error("runtime-sdk: empty prompt on stdin");
  process.exit(2);
}

const systemMd = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), "prompts", "system.md"),
  "utf8",
);

const authStorage = AuthStorage.create();
const modelRegistry = ModelRegistry.create(authStorage);

let model;
if (process.env.ENGINE_MODEL) {
  const [provider, ...id] = process.env.ENGINE_MODEL.split("/");
  model = modelRegistry.find(provider, id.join("/"));
  if (!model) {
    console.error(`runtime-sdk: model not found: ${process.env.ENGINE_MODEL}`);
    process.exit(2);
  }
}

const cwd = process.cwd();
// mirror cli mode isolation: --no-extensions --no-skills --no-prompt-templates --no-context-files
const loader = new DefaultResourceLoader({
  cwd,
  agentDir: getAgentDir(),
  noExtensions: true,
  noSkills: true,
  noPromptTemplates: true,
  noThemes: true,
  noContextFiles: true,
  appendSystemPromptOverride: (base) => [...base, systemMd],
});
await loader.reload();

const { session } = await createAgentSession({
  cwd,
  resourceLoader: loader,
  sessionManager: SessionManager.inMemory(cwd),
  authStorage,
  modelRegistry,
  ...(model ? { model } : {}),
  ...(process.env.ENGINE_THINKING ? { thinkingLevel: process.env.ENGINE_THINKING } : {}),
  ...(process.env.ENGINE_NO_TOOLS === "1" ? { noTools: "all" } : {}),
});

let sawText = false;
session.subscribe((event) => {
  if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
    sawText = true;
    process.stdout.write(event.assistantMessageEvent.delta);
  }
});

try {
  await session.prompt(prompt);
  const err = session.agent.state.errorMessage;
  if (err) {
    console.error(`\nruntime-sdk: agent error: ${err}`);
    process.exit(1);
  }
  if (!sawText) {
    console.error("runtime-sdk: no assistant text produced");
    process.exit(1);
  }
  process.stdout.write("\n");
} finally {
  session.dispose();
}
