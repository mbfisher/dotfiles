import * as fs from "node:fs/promises";
import * as path from "node:path";

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import * as piNatives from "@oh-my-pi/pi-natives";

const UPSTREAM_ISSUE = "https://github.com/can1357/oh-my-pi/issues/11792";
const EXTENSION_PATH = "~/.omp/agent/extensions/protect-existing-files.ts";

const WRITE_POLICY = [
	"Local write safety policy:",
	"- Use `write` only to create a new filesystem file.",
	"- To change an existing filesystem file, use `edit` (or another range-aware editing tool) directly.",
	"- `write` calls targeting existing filesystem files are blocked before any bytes are changed.",
].join("\n");

function unwrapHashlinePath(rawPath: string): string {
	const match = rawPath.match(/^\[([^#\r\n]+)#[^\]\r\n]*\]$/);
	return match?.[1] ?? rawPath;
}

function resolveFilesystemPath(rawPath: string, cwd: string): string | undefined {
	const target = unwrapHashlinePath(rawPath).trim();

	// Internal resources and tool devices have their own write semantics.
	if (/^[a-z][a-z0-9+.-]*:\/\//i.test(target)) return undefined;

	const expanded =
		target === "~"
			? process.env.HOME
			: target.startsWith("~/")
				? path.join(process.env.HOME ?? "~", target.slice(2))
				: target;
	if (!expanded) return undefined;
	return path.isAbsolute(expanded) ? path.normalize(expanded) : path.resolve(cwd, expanded);
}

async function isExistingRegularFile(rawPath: string, cwd: string): Promise<boolean> {
	const resolvedPath = resolveFilesystemPath(rawPath, cwd);
	if (!resolvedPath) return false;

	try {
		return (await fs.stat(resolvedPath)).isFile();
	} catch (error) {
		const code = (error as NodeJS.ErrnoException).code;
		if (code === "ENOENT" || code === "ENOTDIR") return false;
		throw error;
	}
}

function hasUpstreamProjectionGuard(): boolean {
	// This native detector was added as part of the upstream fix. Capability
	// detection avoids a network request and does not depend on release numbers.
	const natives = piNatives as unknown as Record<string, unknown>;
	return typeof natives.hashlineIsReadTruncationNotice === "function";
}

export default function protectExistingFiles(pi: ExtensionAPI) {
	if (hasUpstreamProjectionGuard()) {
		pi.on("session_start", (_event, ctx) => {
			ctx.ui.notify(
				`OMP now includes the upstream fix for ${UPSTREAM_ISSUE}. The local guard at ${EXTENSION_PATH} is inactive and can be removed.`,
				"info",
			);
		});
		return;
	}

	pi.on("before_agent_start", event => ({
		systemPrompt: [...event.systemPrompt, WRITE_POLICY],
	}));

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "write") return;

		const target = event.input.path;
		if (typeof target !== "string" || !(await isExistingRegularFile(target, ctx.cwd))) return;

		return {
			block: true,
			reason:
				`Refusing to overwrite existing file '${target}' with write. ` +
				"Use edit for a targeted change; write is reserved for creating new files.",
		};
	});
}
