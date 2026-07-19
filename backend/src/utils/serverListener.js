function listenWithFriendlyErrors(app, port) {
  const server = app.listen(port, "0.0.0.0", () => {
    console.log(`ReJoy backend running on http://localhost:${port}`);
  });

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
