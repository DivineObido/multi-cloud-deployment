const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;
const CLOUD_PROVIDER = process.env.CLOUD_PROVIDER || 'Unknown';
const NODE_ENV = process.env.NODE_ENV || 'development';

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  const healthStatus = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    cloud_provider: CLOUD_PROVIDER,
    environment: NODE_ENV,
    version: require('./package.json').version,
    memory_usage: process.memoryUsage(),
    cpu_usage: process.cpuUsage()
  };

  res.status(200).json(healthStatus);
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: `Welcome to Multi-Cloud Application running on ${CLOUD_PROVIDER}!`,
    timestamp: new Date().toISOString(),
    cloud_provider: CLOUD_PROVIDER,
    environment: NODE_ENV,
    version: require('./package.json').version,
    request_id: req.headers['x-request-id'] || 'unknown'
  });
});

// API info endpoint
app.get('/api/info', (req, res) => {
  res.json({
    application: 'Multi-Cloud Web App',
    version: require('./package.json').version,
    cloud_provider: CLOUD_PROVIDER,
    environment: NODE_ENV,
    node_version: process.version,
    platform: process.platform,
    architecture: process.arch,
    pid: process.pid,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Metrics endpoint for monitoring
app.get('/metrics', (req, res) => {
  const metrics = {
    memory_usage: process.memoryUsage(),
    cpu_usage: process.cpuUsage(),
    uptime: process.uptime(),
    load_average: require('os').loadavg(),
    total_memory: require('os').totalmem(),
    free_memory: require('os').freemem(),
    platform: process.platform,
    node_version: process.version,
    timestamp: new Date().toISOString(),
    cloud_provider: CLOUD_PROVIDER
  };

  res.json(metrics);
});

// Simulate load for testing
app.post('/api/load', (req, res) => {
  const { duration = 1000 } = req.body;
  const start = Date.now();

  // Simulate CPU intensive task
  while (Date.now() - start < duration) {
    Math.random() * Math.random();
  }

  res.json({
    message: `Load simulation completed in ${Date.now() - start}ms`,
    cloud_provider: CLOUD_PROVIDER,
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    cloud_provider: CLOUD_PROVIDER,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    cloud_provider: CLOUD_PROVIDER,
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully...');
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Multi-Cloud App server running on port ${PORT}`);
  console.log(`Environment: ${NODE_ENV}`);
  console.log(`Cloud Provider: ${CLOUD_PROVIDER}`);
  console.log(`Health check available at: http://localhost:${PORT}/health`);
});

module.exports = app;