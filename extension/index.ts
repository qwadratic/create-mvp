// agentmake demo-mode extension.
// (a) disables all built-in tools, (b) exposes a single `agentmake_demo` tool
// that drives the engine via `make -C <dir>` with progress streaming,
// (c) bundles the `agentic-makefile` skill so plain pi sessions auto-drive
// the goal.md -> plan -> components -> review pipeline.
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	truncateTail,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";

const baseDir = dirname(fileURLToPath(import.meta.url));
const TOOL = "agentmake_demo";
const TARGETS = ["all", "progress", "graph", "clean"] as const;

function tail(text: string, lines: number): string {
	return text.split("\n").slice(-lines).join("\n");
}

function runMake(
	args: string[],
	signal: AbortSignal | undefined,
	onOutput: (accumulated: string) => void,
): Promise<{ output: string; code: number }> {
	return new Promise((resolvePromise, reject) => {
		const child = spawn("make", args, { env: process.env });
		let output = "";
		let lastUpdate = 0;
		const onData = (chunk: Buffer) => {
			output += chunk.toString();
			const now = Date.now();
			if (now - lastUpdate > 250) {
				lastUpdate = now;
				onOutput(output);
			}
		};
		child.stdout.on("data", onData);
		child.stderr.on("data", onData);
		const onAbort = () => child.kill("SIGTERM");
		signal?.addEventListener("abort", onAbort, { once: true });
		child.on("error", reject);
		child.on("close", (code) => {
			signal?.removeEventListener("abort", onAbort);
			resolvePromise({ output, code: code ?? 1 });
		});
	});
}

export default function (pi: ExtensionAPI) {
	// (c) bundle the agentic-makefile skill
	pi.on("resources_discover", () => ({
		skillPaths: [join(baseDir, "skills")],
	}));

	// (a) demo mode: only the demo tool is active.
	// Re-assert per turn too — other (globally installed) extensions may re-enable
	// their tools after our session_start handler ran.
	const lockdown = () => pi.setActiveTools([TOOL]);
	pi.on("session_start", lockdown);
	pi.on("before_agent_start", lockdown);

	// (b) single tool driving the engine
	pi.registerTool({
		name: TOOL,
		label: "agentmake",
		description:
			"Drive the agentmake engine in a demo directory (must contain a Makefile that " +
			"includes engine/build.mk plus a goal.md). Targets: 'all' runs the full pipeline " +
			"(plan -> components -> review) and appends a progress census; 'progress' prints " +
			"the artifact census; 'graph' emits a mermaid dependency graph; 'clean' wipes " +
			"build/ and src/. Output is truncated to the last 50KB/2000 lines.",
		promptSnippet: "Run the agentmake engine (make) in a demo directory with streamed progress",
		promptGuidelines: [
			`Use ${TOOL} to build, inspect, or clean an agentmake demo instead of raw shell commands.`,
			`After ${TOOL} finishes target 'all', report the reviewer verdict from the output; do not re-review by hand.`,
		],
		parameters: Type.Object({
			dir: Type.String({
				description: "Demo directory containing Makefile + goal.md (relative to cwd or absolute)",
			}),
			target: Type.Optional(StringEnum(TARGETS, { description: "make target (default: all)" })),
			jobs: Type.Optional(
				Type.Number({ description: "parallel jobs (make -j), default serial", minimum: 1, maximum: 16 }),
			),
		}),
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const dir = resolve(ctx.cwd, params.dir.replace(/^@/, ""));
			if (!existsSync(join(dir, "Makefile"))) {
				throw new Error(
					`no Makefile in ${dir} — scaffold goal.md + 'include engine/build.mk' first (see agentic-makefile skill)`,
				);
			}
			const target = params.target ?? "all";
			const args = ["-C", dir];
			if (params.jobs) args.push(`-j${params.jobs}`);
			args.push(target);

			onUpdate?.({ content: [{ type: "text", text: `make ${args.join(" ")}` }], details: { dir, target } });
			const { output, code } = await runMake(args, signal, (acc) => {
				onUpdate?.({ content: [{ type: "text", text: tail(acc, 30) }], details: { dir, target } });
			});

			if (signal?.aborted) {
				return { content: [{ type: "text", text: "cancelled" }], details: { dir, target, code } };
			}
			if (code !== 0) {
				throw new Error(`make ${target} failed (exit ${code})\n${tail(output, 60)}`);
			}

			let text = output;
			if (target === "all") {
				const census = await runMake(["-C", dir, "progress"], signal, () => {});
				text += `\n── progress ──\n${census.output}`;
			}
			const t = truncateTail(text, { maxLines: DEFAULT_MAX_LINES, maxBytes: DEFAULT_MAX_BYTES });
			let result = t.content;
			if (t.truncated) {
				result += `\n[truncated: showing last ${t.outputLines} of ${t.totalLines} lines]`;
			}
			return { content: [{ type: "text", text: result }], details: { dir, target, code } };
		},
	});

	// convenience: /demo <dir> [target] hands the run to the agent via the tool
	pi.registerCommand("demo", {
		description: "Drive the agentmake engine: /demo <dir> [all|progress|graph|clean]",
		handler: async (args, ctx) => {
			const [dir, target] = (args ?? "").trim().split(/\s+/).filter(Boolean);
			if (!dir) {
				if (ctx.hasUI) ctx.ui.notify("usage: /demo <dir> [all|progress|graph|clean]", "warning");
				return;
			}
			pi.sendUserMessage(
				`Use the ${TOOL} tool: run target '${target ?? "all"}' in '${dir}', then summarize the result (reviewer verdict, component census).`,
			);
		},
	});
}
