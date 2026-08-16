function listenWithFriendlyErrors(app, port) {
  const server = app.listen(port, "0.0.0.0", () => {
    console.log(`ReJoy backend running on http://localhost:${port}`);
  });

  // Keep connections reusable behind Render's proxy while bounding requests
  // that stop responding. This improves throughput without extra workers.
  server.keepAliveTimeout = Number(process.env.KEEP_ALIVE_TIMEOUT_MS || 65000);
  server.headersTimeout = Number(process.env.HEADERS_TIMEOUT_MS || 66000);
  server.requestTimeout = Number(process.env.REQUEST_TIMEOUT_MS || 30000);
  server.maxRequestsPerSocket = Number(
    process.env.MAX_REQUESTS_PER_SOCKET || 1000,
  );

  server.on("error", (error) => {
    if (error.code === "EADDRINUSE") {
      console.error("");
      console.error(`Port ${port} is already in use.`);
      console.error("Run this in PowerShell, then start backend again:");
      console.error(
        `Get-NetTCPConnection -LocalPort ${port} | Select-Object OwningProcess`,
      );
      console.error("Stop-Process -Id <PID> -Force");
      process.exit(1);
      return;
    }

    console.error("Backend server failed:", error.message);
    process.exit(1);
  });

  return server;
}

module.exports = { listenWithFriendlyErrors };
