const { recordHandledError } = require('../services/runtimeMetrics');

function notFound(req, res) {
  res.status(404).json({
    message: `Route not found: ${req.originalUrl}`,
    requestId: req.requestId,
  });
}

function errorHandler(err, req, res, next) {
  recordHandledError();
  const statusCode = err.statusCode || (res.statusCode && res.statusCode !== 200 ? res.statusCode : 500);
  if (statusCode >= 500) {
    console.error(`[${req.requestId || 'no-request-id'}]`, err);
  }
  res.status(statusCode).json({
    message: err.message || 'Internal Server Error',
    requestId: req.requestId,
    stack: process.env.NODE_ENV === 'production' ? undefined : err.stack,
  });
}

module.exports = {
  errorHandler,
  notFound,
};
