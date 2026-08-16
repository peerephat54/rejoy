const { performance } = require("node:perf_hooks");

const target =
  process.argv[2] ||
  process.env.LOAD_TEST_URL ||
  "http://localhost:3000/api/health/ready";
const total = readInt("LOAD_TEST_TOTAL", 60, 1, 10000);
const concurrency = readInt("LOAD_TEST_CONCURRENCY", 10, 1, 200);
const timeoutMs = readInt("LOAD_TEST_TIMEOUT_MS", 10000, 100, 120000);

function readInt(name, fallback, min, max) {
  const parsed = Number.parseInt(process.env[name], 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function percentile(sorted, ratio) {
  if (sorted.length === 0) return 0;
  const index = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil(sorted.length * ratio) - 1),
  );
  return Number(sorted[index].toFixed(1));
}

async function runRequest(index) {
  const startedAt = performance.now();
  try {
    const response = await fetch(target, {
      headers: {
        accept: "application/json",
        "x-request-id": `load-smoke-${process.pid}-${index}`,
      },
      signal: AbortSignal.timeout(timeoutMs),
    });
    await response.arrayBuffer();
    return {
      ok: response.ok,
      status: response.status,
      durationMs: performance.now() - startedAt,
    };
  } catch (error) {
    const cause = error.cause?.code || error.cause?.message;
    return {
      ok: false,
      status: 0,
      durationMs: performance.now() - startedAt,
      error: cause ? `${error.name}: ${cause}` : error.name,
    };
  }
}

async function main() {
  const durations = [];
  const statuses = new Map();
  const errors = new Map();
  let nextIndex = 0;
  let succeeded = 0;

  async function worker() {
    while (nextIndex < total) {
      const index = nextIndex;
      nextIndex += 1;
      const result = await runRequest(index);
      durations.push(result.durationMs);
      statuses.set(result.status, (statuses.get(result.status) || 0) + 1);
      if (result.ok) {
        succeeded += 1;
      } else if (result.error) {
        errors.set(result.error, (errors.get(result.error) || 0) + 1);
      }
    }
  }

  const startedAt = performance.now();
  await Promise.all(
    Array.from({ length: Math.min(concurrency, total) }, () => worker()),
  );
  const elapsedMs = performance.now() - startedAt;
  durations.sort((a, b) => a - b);

  const summary = {
    target,
    requests: total,
    concurrency: Math.min(concurrency, total),
    succeeded,
    failed: total - succeeded,
    elapsedMs: Number(elapsedMs.toFixed(1)),
    requestsPerSecond: Number((total / (elapsedMs / 1000)).toFixed(2)),
    latencyMs: {
      p50: percentile(durations, 0.5),
      p95: percentile(durations, 0.95),
      p99: percentile(durations, 0.99),
      max: Number((durations.at(-1) || 0).toFixed(1)),
    },
    statuses: Object.fromEntries(statuses),
    errors: Object.fromEntries(errors),
  };

  console.log(JSON.stringify(summary, null, 2));
  if (succeeded !== total) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
