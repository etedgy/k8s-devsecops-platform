const express = require('express');
const promClient = require('prom-client');

const app = express();
const port = process.env.PORT || 8080;
const env = process.env.APP_ENV || 'dev';
const podName = process.env.POD_NAME || 'local';

// --- Metrics registry -------------------------------------------------------
const register = new promClient.Registry();
register.setDefaultLabels({ app: 'web', env });
promClient.collectDefaultMetrics({ register });

// HTTP request counter by method/route/status — this is what the canary
// AnalysisTemplate queries for success-rate (5xx vs total).
const httpRequests = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
});
const httpDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2],
});
register.registerMetric(httpRequests);
register.registerMetric(httpDuration);

const rootAccess = new promClient.Counter({
  name: 'root_access_total',
  help: 'Total number of accesses to the main path',
});
register.registerMetric(rootAccess);

// Middleware: record every request's method/route/status + latency.
app.use((req, res, next) => {
  const end = httpDuration.startTimer();
  res.on('finish', () => {
    const route = req.route ? req.route.path : req.path;
    const labels = { method: req.method, route, status: String(res.statusCode) };
    httpRequests.inc(labels);
    end(labels);
  });
  next();
});

// --- Routes -----------------------------------------------------------------
app.get('/my-app', (req, res) => {
  rootAccess.inc();
  res.json({ msg: 'Hello, World!', env, pod: podName });
});

app.get('/about', (req, res) => {
  res.send('This is a sample Node.js application for Kubernetes deployment testing.');
});

// Probes
app.get('/ready', (req, res) => res.status(200).send('Ready'));
app.get('/live', (req, res) => res.status(200).send('Alive'));
// Alias probe paths (Rollout uses these)
app.get('/readyz', (req, res) => res.status(200).send('Ready'));
app.get('/healthz', (req, res) => res.status(200).send('Alive'));

// CPU burn to exercise the HPA (e.g. /work?ms=200)
app.get('/work', (req, res) => {
  const ms = Math.min(parseInt(req.query.ms, 10) || 100, 2000);
  const until = Date.now() + ms;
  while (Date.now() < until) { Math.sqrt(Math.random()); }
  res.json({ burned_ms: ms, pod: podName });
});

// Fault injection to demonstrate the canary abort (e.g. FAIL_RATE=1 -> all 500)
const failRate = parseFloat(process.env.FAIL_RATE || '0');
app.get('/classified', (req, res) => {
  if (Math.random() < failRate) return res.status(500).send('injected failure');
  res.status(200).send('You should not be here!!!');
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(port, () => console.log(`web listening on :${port} (env=${env})`));
