const startedAt = Date.now();

const state = {
  requests: 0,
  responses2xx: 0,
  responses4xx: 0,
  responses5xx: 0,
  handledErrors: 0,
  totalDurationMs: 0,
  maxDurationMs: 0,
  inFlight: 0,
  peakInFlight: 0,
};

function recordRequestStart() {
  state.requests += 1;
  state.inFlight += 1;
  state.peakInFlight = Math.max(state.peakInFlight, state.inFlight);
}

function recordRequestFinish(statusCode, durationMs) {
  state.inFlight = Math.max(0, state.inFlight - 1);
  state.totalDurationMs += durationMs;
  state.maxDurationMs = Math.max(state.maxDurationMs, durationMs);
  if (statusCode >= 500) state.responses5xx += 1;
  else if (statusCode >= 400) state.responses4xx += 1;
  else if (statusCode >= 200) state.responses2xx += 1;
}

function recordHandledError() {
  state.handledErrors += 1;
}

function snapshot() {
  const completed = state.responses2xx + state.responses4xx + state.responses5xx;
  const memory = process.memoryUsage();
  return {
    startedAt: new Date(startedAt).toISOString(),
    uptimeSeconds: Math.round(process.uptime()),
    requests: state.requests,
    inFlight: state.inFlight,
    peakInFlight: state.peakInFlight,
    responses: {
      success: state.responses2xx,
      clientError: state.responses4xx,
      serverError: state.responses5xx,
    },
    handledErrors: state.handledErrors,
    averageDurationMs:
      completed === 0 ? 0 : Number((state.totalDurationMs / completed).toFixed(2)),
    maxDurationMs: Number(state.maxDurationMs.toFixed(2)),
    memoryMb: {
      rss: Number((memory.rss / 1024 / 1024).toFixed(1)),
      heapUsed: Number((memory.heapUsed / 1024 / 1024).toFixed(1)),
    },
  };
}

module.exports = {
  recordHandledError,
  recordRequestFinish,
  recordRequestStart,
  snapshot,
};
