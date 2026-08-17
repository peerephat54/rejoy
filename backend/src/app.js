const cors = require('cors');
const compression = require('compression');
const express = require('express');
const mongoSanitize = require('express-mongo-sanitize');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const hpp = require('hpp');
const morgan = require('morgan');
const { randomUUID } = require('crypto');

const authRoutes = require('./routes/authRoutes');
const healthRoutes = require('./routes/healthRoutes');
const chatRoutes = require('./routes/chatRoutes');
const clinicalRoutes = require('./routes/clinicalRoutes');
const questRoutes = require('./routes/questRoutes');
const reportRoutes = require('./routes/reportRoutes');
const userRoutes = require('./routes/userRoutes');
const { errorHandler, notFound } = require('./middleware/errorMiddleware');
const runtimeMetrics = require('./services/runtimeMetrics');

const app = express();

function noStore(req, res, next) {
  res.set('Cache-Control', 'no-store');
  next();
}

function cacheFor(seconds) {
  return (req, res, next) => {
    res.set('Cache-Control', `private, max-age=${seconds}`);
    next();
  };
}

app.set('etag', 'weak');
app.set('trust proxy', 1);

app.use((req, res, next) => {
  const requestId = req.get('x-request-id') || randomUUID();
  req.requestId = requestId;
  res.set('x-request-id', requestId);
  next();
});

app.use((req, res, next) => {
  const startedAt = process.hrtime.bigint();
  runtimeMetrics.recordRequestStart();
  res.once('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1e6;
    runtimeMetrics.recordRequestFinish(res.statusCode, durationMs);
  });
  next();
});

const allowedOrigins = (process.env.CORS_ORIGIN || '*')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(helmet());
app.use(compression());
app.use(
  cors({
    origin(origin, callback) {
      if (allowedOrigins.includes('*') || !origin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Not allowed by CORS'));
    },
  }),
);
app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: Number(process.env.RATE_LIMIT_MAX || 300),
    standardHeaders: 'draft-7',
    legacyHeaders: false,
  }),
);
app.use('/api/auth', rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: Number(process.env.AUTH_RATE_LIMIT_MAX || 20),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
}));
app.use(express.json({ limit: '250kb' }));
app.use(express.urlencoded({ extended: true }));
app.use(mongoSanitize());
app.use(hpp());
app.use(
  morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev', {
    skip: (req) => req.path === '/api/health' || req.path === '/api/health/ready',
  }),
);

app.get('/', (req, res) => {
  res.json({
    message: 'ReJoy Backend API',
    endpoints: ['/api/health', '/api/users', '/api/quests', '/api/reports', '/api/clinical/dashboard'],
  });
});

app.use('/api/chat', noStore, chatRoutes);
app.use('/api/clinical', noStore, clinicalRoutes);
app.use('/api/auth', noStore, authRoutes);
app.use('/api/health', noStore, healthRoutes);
app.use('/api/users', noStore, userRoutes);
app.use('/api/quests', cacheFor(60), questRoutes);
app.use('/api/reports', noStore, reportRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
