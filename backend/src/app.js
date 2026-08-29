const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const cookieParser = require('cookie-parser');
const morgan = require('morgan');
const config = require('./config');
const routes = require('./routes');
const { errorHandler, notFoundHandler, globalLimiter } = require('./middleware');

const app = express();

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(
  cors({
    // Support comma-separated FRONTEND_URL for GitHub Pages + local
    origin: config.nodeEnv === 'production' ? config.frontend.url.split(',').map(s=>s.trim()).filter(Boolean) : true,
    credentials: true,
  })
);
app.use(compression());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
app.use(cookieParser());
if (config.nodeEnv !== 'test') {
  app.use(morgan('dev'));
}
app.use(globalLimiter);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

// Friendly landing for anyone opening the API root in a browser.
app.get('/', (req, res) => {
  res.json({
    name: 'Spotify-FY API',
    status: 'ok',
    health: '/health',
    endpoints: '/api',
  });
});

app.use('/api', routes);

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;