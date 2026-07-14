#!/usr/bin/env node

export const PRODUCTION_RUNBOOK = "docs/PRODUCTION_READINESS_RUNBOOK.md";

export const DEPLOYMENT_BLOCKERS = Object.freeze([
  "Eligible competitive evidence production is missing: the local " +
    "server-observation substrate remains disabled and ineligible, has no " +
    "calibrated deterministic evaluator, and lacks cross-account replay, " +
    "retention, and live-provider evidence.",
  "Reciprocal friendship authority is missing; implement and verify it " +
    "before deployment.",
  "Independently trusted deployment authorization evidence is missing; " +
    "obtain and verify it before deployment.",
  "An immutable source-bound deployment artifact is missing; build and " +
    "verify it before deployment.",
]);

export class BackendDeployUnavailableError extends Error {
  constructor(message) {
    super(message);
    this.name = "BackendDeployUnavailableError";
  }
}

export function parseBackendDeployArguments(args) {
  if (args.length === 0) return {help: false};
  if (args.length === 1 && args[0] === "--help") return {help: true};
  throw new BackendDeployUnavailableError(
    `Unsupported deployment argument: ${args[0] ?? "unknown"}. ` +
    "Backend deployment has no execute path."
  );
}

export function backendDeployHelp() {
  return [
    "Backend deployment is intentionally unavailable.",
    "",
    "Noum does not currently expose an authorization or execute path.",
    `Follow ${PRODUCTION_RUNBOOK} to close the required release gates.`,
    "",
  ].join("\n");
}

export function backendDeployRefusal() {
  return [
    "Backend deployment refused.",
    ...DEPLOYMENT_BLOCKERS.map((blocker) => `- ${blocker}`),
    `See ${PRODUCTION_RUNBOOK}.`,
    "",
  ].join("\n");
}

const isMain = process.argv[1]?.endsWith("release-backend-deploy.mjs") === true;
if (isMain) {
  try {
    const options = parseBackendDeployArguments(process.argv.slice(2));
    if (options.help) {
      process.stdout.write(backendDeployHelp());
    } else {
      process.stderr.write(backendDeployRefusal());
      process.exitCode = 1;
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown argument.";
    process.stderr.write(`${message}\n${backendDeployRefusal()}`);
    process.exitCode = 2;
  }
}
