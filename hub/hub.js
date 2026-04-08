/**
 * NeuralBox Hub Server v1.0
 * Unified portal at http://localhost:8080
 * No npm dependencies — Node.js built-ins only (requires Node 18+)
 */

'use strict';

const http   = require('http');
const fs     = require('fs');
const path   = require('path');
const os     = require('os');
const crypto = require('crypto');

const PORT       = 8080;
const HUB_DIR    = __dirname;
const HOME_DIR   = process.env.USERPROFILE || process.env.HOME || os.homedir();
const START_TIME = Date.now();
let   requestCount = 0;

// ── Session token ─────────────────────────────────────────────────────────────
// One random token per hub process. Persisted across restarts.
// Stored at ~/.neuralbox/hub-token (not in project dir).
// Privileged write endpoints require this token via cookie or header.

const TOKEN_FILE = path.join(HOME_DIR, '.neuralbox', 'hub-token');
let   HUB_TOKEN  = null;

(function loadOrCreateToken() {
  try {
    if (fs.existsSync(TOKEN_FILE)) {
      const t = fs.readFileSync(TOKEN_FILE, 'utf8').trim();
      if (t && t.length >= 32) { HUB_TOKEN = t; return; }
    }
  } catch {}
  HUB_TOKEN = crypto.randomBytes(32).toString('hex');
  try {
    const dir = path.dirname(TOKEN_FILE);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(TOKEN_FILE, HUB_TOKEN, { mode: 0o600, encoding: 'utf8' });
  } catch (e) {
    console.warn(`[NeuralBox] WARNING: could not persist hub token: ${e.message}`);
  }
})();

function parseCookies(header) {
  const out = {};
  if (!header) return out;
  for (const part of header.split(';')) {
    const idx = part.indexOf('=');
    if (idx < 0) continue;
    out[part.slice(0, idx).trim()] = part.slice(idx + 1).trim();
  }
  return out;
}

/** Returns true if request carries a valid hub session token. */
function validateAuth(req) {
  const cookies = parseCookies(req.headers['cookie']);
  if (cookies['nb_session'] === HUB_TOKEN) return true;
  const auth = req.headers['authorization'] || '';
  if (auth.startsWith('Bearer ') && auth.slice(7) === HUB_TOKEN) return true;
  if ((req.headers['x-hub-token'] || '') === HUB_TOKEN) return true;
  return false;
}

/** For privileged write endpoints: must be local origin AND carry token. */
function isAuthorizedWrite(req) {
  if (!isLocalOrigin(req)) return false;
  return validateAuth(req);
}

// Load modules
const storage    = require('./storage.js');
const { generate, testApiKey, serviceAlive } = require('./efficiency.js');
const { MONEY_TOOLS, QUICK_TEMPLATES, WORKERS, TEMPLATE_CATEGORIES } = require('./templates.js');
const { listProfiles, recommendProfile } = require('./router.js');

// Legacy paths
const MEMORY_JSON        = path.join(HOME_DIR, '.clawbot_memory.json');
const OPENCLAW_WORKSPACE = path.join(HOME_DIR, '.openclaw', 'workspace');
const OPENCLAW_MEMORY_MD = path.join(OPENCLAW_WORKSPACE, 'MEMORY.md');

// ── In-memory worker queue ─────────────────────────────────────────────────────

const workerQueue = [];   // { id, type, title, input, profile, budget_cap, status, progress, stage, provider, model, cost_label, result, error, created_at }
let   workerRunning = false;

async function processWorkerQueue() {
  if (workerRunning) return;
  const job = workerQueue.find(j => j.status === 'queued');
  if (!job) return;

  workerRunning = true;
  job.status   = 'running';
  job.progress = 5;

  try {
    const settings   = storage.loadUserSettings();
    const template   = WORKERS.find(w => w.id === job.type);
    const systemPrompt = template ? template.system_prompt : 'You are a helpful AI assistant.';

    // Build user prompt from job input fields
    let userPrompt = '';
    if (template && template.fields) {
      for (const f of template.fields) {
        const val = job.input[f.id];
        if (val) userPrompt += `${f.label}: ${val}\n`;
      }
    } else {
      userPrompt = typeof job.input === 'string' ? job.input : JSON.stringify(job.input);
    }

    job.progress = 20;
    job.stage    = 'stage1';

    const result = await generate({
      systemPrompt,
      userPrompt,
      taskType:          job.type || 'worker',
      profileName:       job.profile || settings.routing_rules?.workers || 'Balanced',
      settings,
      maxStage:          2,
      budgetCap:         job.budget_cap != null ? job.budget_cap : null,
      jobId:             job.id,
      confirmedExpensive: true, // budget pre-checked at queue time
    });

    job.progress   = 100;
    job.status     = 'done';
    job.result     = result.result;
    job.provider   = result.provider;
    job.model      = result.model_used;
    job.cost_label = result.cost_label;
    job.cost_usd   = result.cost_usd;
    job.tokens     = result.tokens;
    job.spend      = result.spend;

    // Auto-save to history
    storage.saveOutput({
      title:      `Worker: ${job.title}`,
      content:    result.result,
      task_type:  job.type,
      model_used: result.model_used,
      provider:   result.provider,
      cost_label: result.cost_label,
      cost_usd:   result.cost_usd,
      tokens:     result.tokens,
    });

  } catch (err) {
    job.status = 'error';
    job.error  = err.message;
    job.progress = 0;
  }

  workerRunning = false;
  // Process next job in queue
  setImmediate(processWorkerQueue);
}

// ── Helpers ────────────────────────────────────────────────────────────────────

async function ping(url, timeoutMs = 2000) {
  return serviceAlive(url, timeoutMs);
}

function readMemory() {
  try {
    return JSON.parse(fs.readFileSync(MEMORY_JSON, 'utf8'));
  } catch {
    return { facts: [] };
  }
}

function syncMemoryToOpenClaw() {
  try {
    const data  = readMemory();
    const facts = data.facts || [];
    if (facts.length === 0) return;
    const groups = {};
    for (const f of facts) {
      const cat = (f.category || 'general').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
      if (!groups[cat]) groups[cat] = [];
      groups[cat].push(f.fact);
    }
    let md = '# User Memory\n_Auto-synced from NeuralBox._\n\n';
    for (const [cat, items] of Object.entries(groups)) {
      md += `## ${cat}\n`;
      for (const item of items) md += `- ${item}\n`;
      md += '\n';
    }
    if (!fs.existsSync(OPENCLAW_WORKSPACE)) fs.mkdirSync(OPENCLAW_WORKSPACE, { recursive: true });
    fs.writeFileSync(OPENCLAW_MEMORY_MD, md, 'utf8');
  } catch { /* non-critical */ }
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; if (body.length > 1_000_000) req.destroy(); });
    req.on('end', () => {
      try { resolve(JSON.parse(body || '{}')); }
      catch { resolve({}); }
    });
    req.on('error', reject);
  });
}

// ── CORS / Origin guard ───────────────────────────────────────────────────────

const ALLOWED_ORIGINS = new Set([
  'http://localhost:8080',
  'http://127.0.0.1:8080',
]);

function isLocalOrigin(req) {
  const origin = req.headers['origin'];
  const host   = req.headers['host'];
  if (!origin) return true;                     // non-browser (curl, scripts)
  if (ALLOWED_ORIGINS.has(origin)) return true; // hub's own UI
  return false;
}

function json(res, statusCode, data) {
  const body = JSON.stringify(data);
  res.writeHead(statusCode, {
    'Content-Type':  'application/json',
    'Cache-Control': 'no-cache',
  });
  res.end(body);
}

// ── Hardware info ─────────────────────────────────────────────────────────────

async function getHardwareInfo() {
  const totalMem  = os.totalmem();
  const freeMem   = os.freemem();
  const ram_gb    = parseFloat((totalMem / 1024 ** 3).toFixed(1));
  const ram_free  = parseFloat((freeMem  / 1024 ** 3).toFixed(1));

  // Get disk info (best-effort on Windows and Unix)
  let disk_gb = null;
  let disk_free = null;
  try {
    const { execSync } = require('child_process');
    if (process.platform === 'win32') {
      const out = execSync('wmic logicaldisk get size,freespace,caption', { timeout: 3000 }).toString();
      const lines = out.split('\n').filter(l => l.match(/C:/i));
      if (lines[0]) {
        const parts = lines[0].trim().split(/\s+/);
        if (parts.length >= 3) {
          disk_free = parseFloat((parseInt(parts[1]) / 1024 ** 3).toFixed(1));
          disk_gb   = parseFloat((parseInt(parts[2]) / 1024 ** 3).toFixed(1));
        }
      }
    } else {
      const out = execSync('df -BG / 2>/dev/null || df -g / 2>/dev/null', { timeout: 3000 }).toString();
      const line = out.split('\n')[1];
      if (line) {
        const parts = line.trim().split(/\s+/);
        disk_gb   = parseInt(parts[1]) || null;
        disk_free = parseInt(parts[3]) || null;
      }
    }
  } catch { /* disk info unavailable */ }

  // Get Ollama models
  let models = [];
  let recommended = null;
  try {
    const ctrl  = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 2000);
    const r     = await fetch('http://localhost:11434/api/tags', { signal: ctrl.signal });
    clearTimeout(timer);
    if (r.ok) {
      const data = await r.json();
      models = (data.models || []).map(m => ({
        name:     m.name,
        size_gb:  m.size ? parseFloat((m.size / 1024 ** 3).toFixed(1)) : null,
      }));
      if (models.length > 0) recommended = models[0].name;
    }
  } catch { /* ollama offline */ }

  const settings      = storage.loadUserSettings();

  return {
    ram_gb,
    ram_free_gb: ram_free,
    disk_gb,
    disk_free_gb: disk_free,
    models,
    recommended: recommended || settings.primary_model || 'qwen3.5:9b',
    first_run_done: settings.first_run_done || false,
    platform: process.platform,
  };
}

// ── Update-server proxy helper ────────────────────────────────────────────────
// Forwards requests to localhost:9999 with the hub token as X-Hub-Token.
// Uses built-in http module — no external deps.

const UPDATE_SERVER_PORT = 9999;

function proxyToUpdateServer(method, path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port:     UPDATE_SERVER_PORT,
      path,
      method,
      headers: {
        'Content-Type':  'application/json',
        'X-Hub-Token':   HUB_TOKEN,
      },
    };
    const req = http.request(options, (upRes) => {
      let data = '';
      upRes.on('data', chunk => data += chunk);
      upRes.on('end', () => {
        try   { resolve({ status: upRes.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: upRes.statusCode, body: { raw: data } }); }
      });
    });
    req.on('error', reject);
    req.setTimeout(12000, () => { req.destroy(); reject(new Error('update server timeout')); });
    if (method === 'POST') req.write('{}');
    req.end();
  });
}

// ── Request handler ────────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  const urlObj  = new URL(req.url, `http://localhost:${PORT}`);
  const url     = urlObj.pathname;
  const method  = req.method.toUpperCase();

  // CORS preflight — only allow localhost origins
  if (method === 'OPTIONS') {
    const origin = req.headers['origin'];
    const allowOrigin = (origin && ALLOWED_ORIGINS.has(origin)) ? origin : 'http://localhost:8080';
    res.writeHead(204, {
      'Access-Control-Allow-Origin':  allowOrigin,
      'Access-Control-Allow-Methods': 'GET,POST,DELETE',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    res.end();
    return;
  }

  // Block privileged write requests from non-local origins or without valid token.
  // Browser requests (with Origin header): must be local origin + valid session cookie.
  // CLI/script requests (no Origin header): must carry X-Hub-Token or Authorization: Bearer.
  const isWritePath = method === 'POST' || method === 'DELETE' ||
    !!url.match(/^\/api\/history\/.+\/favorite$/);
  if (isWritePath && !isAuthorizedWrite(req)) {
    res.writeHead(403, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'forbidden: authentication required' }));
    return;
  }

  // ── GET /api/token — return session token to local scripts (no-browser only) ──
  if (url === '/api/token' && method === 'GET') {
    if (req.headers['origin']) {
      return json(res, 403, { error: 'forbidden: use hub UI for browser access' });
    }
    return json(res, 200, { token: HUB_TOKEN, file: TOKEN_FILE });
  }

  // ── Static: serve index.html — set session cookie ────────────────────────
  if ((url === '/' || url === '/index.html') && method === 'GET') {
    requestCount++;
    try {
      const html = fs.readFileSync(path.join(HUB_DIR, 'index.html'), 'utf8');
      res.writeHead(200, {
        'Content-Type':  'text/html; charset=utf-8',
        'Set-Cookie':    `nb_session=${HUB_TOKEN}; HttpOnly; SameSite=Strict; Path=/`,
        'Cache-Control': 'no-store',
      });
      res.end(html);
    } catch {
      res.writeHead(500);
      res.end('Hub page not found.');
    }
    return;
  }

  // ── GET /api/status ───────────────────────────────────────────────────────
  if (url === '/api/status' && method === 'GET') {
    const [ollama, webui, openclaw] = await Promise.all([
      ping('http://localhost:11434/api/tags'),
      ping('http://localhost:3000'),
      ping('http://localhost:18789'),
    ]);
    return json(res, 200, { ollama, webui, openclaw });
  }

  // ── GET /api/stats ────────────────────────────────────────────────────────
  if (url === '/api/stats' && method === 'GET') {
    const memData   = readMemory();
    const settings  = storage.loadUserSettings();
    const spend     = storage.getSpend(settings);
    const uptime    = Math.floor((Date.now() - START_TIME) / 1000);
    return json(res, 200, {
      memoryCount:   (memData.facts || []).length,
      uptimeSeconds: uptime,
      requestCount,
      toolsReady:    13,
      spend,
    });
  }

  // ── GET /api/memory ───────────────────────────────────────────────────────
  if (url === '/api/memory' && method === 'GET') {
    return json(res, 200, readMemory());
  }

  // ── GET /api/model ────────────────────────────────────────────────────────
  if (url === '/api/model' && method === 'GET') {
    const settings = storage.loadUserSettings();
    let   available = false;
    let   modelName = settings.primary_model || 'qwen3.5:9b';
    try {
      const ctrl  = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 2000);
      const r     = await fetch('http://localhost:11434/api/tags', { signal: ctrl.signal });
      clearTimeout(timer);
      if (r.ok) {
        available = true;
        const data = await r.json();
        if (data.models && data.models.length > 0) modelName = data.models[0].name;
      }
    } catch { /* offline */ }
    return json(res, 200, { name: modelName, available });
  }

  // ── GET /api/onboarding ───────────────────────────────────────────────────
  if (url === '/api/onboarding' && method === 'GET') {
    const hw = await getHardwareInfo();
    return json(res, 200, hw);
  }

  // ── GET /api/templates ────────────────────────────────────────────────────
  if (url === '/api/templates' && method === 'GET') {
    return json(res, 200, {
      money_tools:  MONEY_TOOLS.map(t => ({ ...t, system_prompt: undefined })),
      quick_templates: QUICK_TEMPLATES.map(t => ({ ...t, system_prompt: undefined })),
      workers: WORKERS.map(w => ({ ...w, system_prompt: undefined })),
      profiles: listProfiles(),
    });
  }

  // ── POST /api/generate ────────────────────────────────────────────────────
  if (url === '/api/generate' && method === 'POST') {
    requestCount++;
    const body = await readBody(req);
    const { template_id, task_type, profile, fields, prompt, max_stage } = body;

    // Resolve template
    let systemPrompt = 'You are a helpful AI assistant. Respond clearly and concisely.';
    let userPrompt   = prompt || '';
    let resolvedTask = task_type || 'template';

    // Look up in Money Tools
    const moneyTool = template_id ? MONEY_TOOLS.find(t => t.id === template_id) : null;
    const quickTpl  = template_id ? QUICK_TEMPLATES.find(t => t.id === template_id) : null;

    if (moneyTool) {
      systemPrompt  = moneyTool.system_prompt;
      resolvedTask  = moneyTool.task_type;
      if (!userPrompt && fields) {
        userPrompt = moneyTool.fields.map(f => `${f.label}: ${fields[f.id] || ''}`).join('\n');
      }
    } else if (quickTpl) {
      systemPrompt  = quickTpl.system_prompt;
      resolvedTask  = quickTpl.task_type;
      if (!userPrompt && fields) {
        userPrompt = `${quickTpl.field_label}: ${fields.input || fields[Object.keys(fields)[0]] || ''}`;
      }
    }

    if (!userPrompt.trim()) {
      return json(res, 400, { error: 'Prompt or fields required' });
    }

    const settings = storage.loadUserSettings();

    try {
      const result = await generate({
        systemPrompt,
        userPrompt,
        taskType:          resolvedTask,
        profileName:       profile || settings.routing_rules?.[resolvedTask] || null,
        settings,
        maxStage:          max_stage || 2,
        confirmedExpensive: body.confirmed_expensive || false,
      });

      // ask_before_expensive gate — signal UI to show confirmation dialog
      if (result.confirmation_required) {
        return json(res, 200, result);
      }

      // Auto-save to history
      const saved = storage.saveOutput({
        title:      moneyTool?.title || quickTpl?.title || resolvedTask,
        content:    result.result,
        task_type:  resolvedTask,
        template_id,
        model_used: result.model_used,
        provider:   result.provider,
        cost_label: result.cost_label,
        cost_usd:   result.cost_usd,
        tokens:     result.tokens,
        input:      fields || { prompt },
      });

      return json(res, 200, { ...result, history_id: saved.id });
    } catch (err) {
      return json(res, 500, { error: err.message });
    }
  }

  // ── GET /api/history ──────────────────────────────────────────────────────
  if (url === '/api/history' && method === 'GET') {
    const q      = urlObj.searchParams.get('q')         || '';
    const filter = urlObj.searchParams.get('filter')    || 'all';
    const limit  = parseInt(urlObj.searchParams.get('limit') || '50');

    let history = storage.loadHistory();

    if (q) {
      const lq = q.toLowerCase();
      history = history.filter(h =>
        (h.title   || '').toLowerCase().includes(lq) ||
        (h.content || '').toLowerCase().includes(lq)
      );
    }
    if (filter === 'favorites') history = history.filter(h => h.favorite);
    if (filter === 'today') {
      const today = new Date().toISOString().slice(0, 10);
      history = history.filter(h => (h.created_at || '').startsWith(today));
    }

    return json(res, 200, history.slice(0, limit));
  }

  // ── POST /api/history/save ────────────────────────────────────────────────
  if (url === '/api/history/save' && method === 'POST') {
    const body  = await readBody(req);
    const saved = storage.saveOutput(body);
    return json(res, 200, saved);
  }

  // ── DELETE /api/history/:id ───────────────────────────────────────────────
  if (url.startsWith('/api/history/') && method === 'DELETE') {
    const id = url.replace('/api/history/', '');
    storage.deleteOutput(id);
    return json(res, 200, { deleted: id });
  }

  // ── POST /api/history/:id/favorite ───────────────────────────────────────
  if (url.match(/^\/api\/history\/.+\/favorite$/) && method === 'POST') {
    const id = url.replace('/api/history/', '').replace('/favorite', '');
    const newState = storage.toggleFavorite(id);
    return json(res, 200, { favorite: newState });
  }

  // ── GET /api/settings ─────────────────────────────────────────────────────
  if (url === '/api/settings' && method === 'GET') {
    const settings = storage.loadUserSettings();
    return json(res, 200, storage.settingsForUI(settings));
  }

  // ── POST /api/settings ────────────────────────────────────────────────────
  if (url === '/api/settings' && method === 'POST') {
    const body    = await readBody(req);
    const updated = storage.saveUserSettings(body);
    return json(res, 200, storage.settingsForUI(updated));
  }

  // ── POST /api/keys/test ───────────────────────────────────────────────────
  if (url === '/api/keys/test' && method === 'POST') {
    const { provider, key } = await readBody(req);
    if (!provider || !key) return json(res, 400, { error: 'provider and key required' });
    const result = await testApiKey(provider, key);
    return json(res, 200, result);
  }

  // ── POST /api/worker/start ────────────────────────────────────────────────
  if (url === '/api/worker/start' && method === 'POST') {
    const body     = await readBody(req);
    const { type, input, profile, budget_cap } = body;

    // Pre-check budget before queuing
    const settings    = storage.loadUserSettings();
    const spendInfo   = storage.getSpend(settings);
    if (spendInfo.locked) {
      return json(res, 429, { error: `Daily budget limit ($${settings.daily_limit_usd}) reached. Reset at midnight or increase limit in Settings.` });
    }
    if (spendInfo.premium_locked && profile !== 'Local Only') {
      return json(res, 429, { error: `Daily premium call limit (${settings.premium_calls_per_day}) reached. Use Local Only profile or wait until midnight.` });
    }

    const template = WORKERS.find(w => w.id === type);
    const job = {
      id:         `wk_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      type:       type || 'idea_worker',
      title:      template?.title || type,
      input:      input || {},
      profile:    profile || null,
      budget_cap: budget_cap != null ? budget_cap : settings.per_worker_budget_usd,
      status:     'queued',
      progress:   0,
      stage:      null,
      provider:   null,
      model:      null,
      cost_label: null,
      cost_usd:   null,
      tokens:     null,
      result:     null,
      error:      null,
      created_at: new Date().toISOString(),
    };
    workerQueue.push(job);
    setImmediate(processWorkerQueue);
    return json(res, 200, { job_id: job.id, status: 'queued' });
  }

  // ── GET /api/worker/status ────────────────────────────────────────────────
  if (url === '/api/worker/status' && method === 'GET') {
    const jobId = urlObj.searchParams.get('id');
    const queue = jobId
      ? workerQueue.filter(j => j.id === jobId)
      : workerQueue.slice(-20);  // last 20 jobs
    return json(res, 200, { queue });
  }

  // ── GET /api/profiles ─────────────────────────────────────────────────────
  if (url === '/api/profiles' && method === 'GET') {
    return json(res, 200, listProfiles());
  }

  // ── Updater proxy (/api/updater/*) ────────────────────────────────────────
  // Proxies requests to the update server (localhost:9999) with the hub token.
  // Read-only endpoints (status, health) are open; write endpoints are protected.

  if (url === '/api/updater/status' && method === 'GET') {
    try {
      const r = await proxyToUpdateServer('GET', '/api/status');
      return json(res, r.status, r.body);
    } catch (err) {
      return json(res, 503, { error: 'Update server not reachable', detail: err.message });
    }
  }

  if (url === '/api/updater/health' && method === 'GET') {
    try {
      const r = await proxyToUpdateServer('GET', '/api/health');
      return json(res, r.status, r.body);
    } catch (err) {
      return json(res, 503, { error: 'Update server not reachable', detail: err.message });
    }
  }

  if (url === '/api/updater/trigger' && method === 'POST') {
    // isAuthorizedWrite already enforced above for all POST requests
    try {
      const r = await proxyToUpdateServer('POST', '/api/update');
      return json(res, r.status, r.body);
    } catch (err) {
      return json(res, 503, { error: 'Update server not reachable', detail: err.message });
    }
  }

  if (url === '/api/updater/reset' && method === 'POST') {
    // isAuthorizedWrite already enforced above for all POST requests
    try {
      const r = await proxyToUpdateServer('POST', '/api/reset');
      return json(res, r.status, r.body);
    } catch (err) {
      return json(res, 503, { error: 'Update server not reachable', detail: err.message });
    }
  }

  // 404
  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not found');
});

// ── Start ──────────────────────────────────────────────────────────────────────

server.listen(PORT, '127.0.0.1', () => {
  console.log('');
  console.log('  ███╗   ██╗███████╗██╗   ██╗██████╗  █████╗ ██╗      ██████╗  ██████╗ ██╗  ██╗');
  console.log('  ████╗  ██║██╔════╝██║   ██║██╔══██╗██╔══██╗██║     ██╔══██╗██╔═══██╗╚██╗██╔╝');
  console.log('  ██╔██╗ ██║█████╗  ██║   ██║██████╔╝███████║██║     ██████╔╝██║   ██║ ╚███╔╝ ');
  console.log('  ██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██╔══██║██║     ██╔══██╗██║   ██║ ██╔██╗ ');
  console.log('  ██║ ╚████║███████╗╚██████╔╝██║  ██║██║  ██║███████╗██████╔╝╚██████╔╝██╔╝ ██╗');
  console.log('  ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝');
  console.log('');
  console.log(`  NeuralBox v1.0  ·  http://localhost:${PORT}`);
  console.log('');
});

syncMemoryToOpenClaw();
setInterval(syncMemoryToOpenClaw, 30_000);
