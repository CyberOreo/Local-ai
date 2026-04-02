/**
 * NeuralBox Hub Server
 * Serves the unified portal at http://localhost:8080
 * No npm dependencies — Node.js built-ins only (requires Node 18+)
 */

const http = require('http');
const fs   = require('fs');
const path = require('path');

const PORT      = 8080;
const HUB_DIR   = __dirname;
const HOME_DIR  = process.env.USERPROFILE || process.env.HOME || '';
const START_TIME = Date.now();
let   requestCount = 0;

const MEMORY_JSON        = path.join(HOME_DIR, '.clawbot_memory.json');
const OPENCLAW_WORKSPACE = path.join(HOME_DIR, '.openclaw', 'workspace');
const OPENCLAW_MEMORY_MD = path.join(OPENCLAW_WORKSPACE, 'MEMORY.md');

// ── Helpers ────────────────────────────────────────────────────────────────

async function ping(url, timeoutMs = 2000) {
  try {
    const ctrl  = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    const res   = await fetch(url, { signal: ctrl.signal });
    clearTimeout(timer);
    return res.status < 500;
  } catch {
    return false;
  }
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
      const cat = (f.category || 'general')
        .replace(/_/g, ' ')
        .replace(/\b\w/g, c => c.toUpperCase());
      if (!groups[cat]) groups[cat] = [];
      groups[cat].push(f.fact);
    }

    let md = '# User Memory\n_Auto-synced from NeuralBox. Do not edit manually._\n\n';
    for (const [cat, items] of Object.entries(groups)) {
      md += `## ${cat}\n`;
      for (const item of items) md += `- ${item}\n`;
      md += '\n';
    }

    if (!fs.existsSync(OPENCLAW_WORKSPACE)) fs.mkdirSync(OPENCLAW_WORKSPACE, { recursive: true });
    fs.writeFileSync(OPENCLAW_MEMORY_MD, md, 'utf8');
  } catch { /* non-critical */ }
}

// ── Request handler ────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  const url = req.url.split('?')[0];

  if (url === '/' || url === '/index.html') {
    requestCount++;
    try {
      const html = fs.readFileSync(path.join(HUB_DIR, 'index.html'), 'utf8');
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
    } catch {
      res.writeHead(500);
      res.end('NeuralBox hub page not found.');
    }
    return;
  }

  if (url === '/api/status') {
    const [ollama, webui, openclaw] = await Promise.all([
      ping('http://localhost:11434/api/tags'),
      ping('http://localhost:3000'),
      ping('http://localhost:18789'),
    ]);
    res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-cache' });
    res.end(JSON.stringify({ ollama, webui, openclaw }));
    return;
  }

  if (url === '/api/memory') {
    const data = readMemory();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(data));
    return;
  }

  if (url === '/api/model') {
    let modelName = 'qwen3.5:9b';
    let available = false;
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
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ name: modelName, available }));
    return;
  }

  if (url === '/api/stats') {
    const memData  = readMemory();
    const uptimeSec = Math.floor((Date.now() - START_TIME) / 1000);
    res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-cache' });
    res.end(JSON.stringify({
      memoryCount:   (memData.facts || []).length,
      uptimeSeconds: uptimeSec,
      requestCount:  requestCount,
      toolsReady:    13,
    }));
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

// ── Start ──────────────────────────────────────────────────────────────────

server.listen(PORT, '127.0.0.1', () => {
  console.log('');
  console.log('  ███╗   ██╗███████╗██╗   ██╗██████╗  █████╗ ██╗      ██████╗  ██████╗ ██╗  ██╗');
  console.log('  ████╗  ██║██╔════╝██║   ██║██╔══██╗██╔══██╗██║     ██╔══██╗██╔═══██╗╚██╗██╔╝');
  console.log('  ██╔██╗ ██║█████╗  ██║   ██║██████╔╝███████║██║     ██████╔╝██║   ██║ ╚███╔╝ ');
  console.log('  ██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██╔══██║██║     ██╔══██╗██║   ██║ ██╔██╗ ');
  console.log('  ██║ ╚████║███████╗╚██████╔╝██║  ██║██║  ██║███████╗██████╔╝╚██████╔╝██╔╝ ██╗');
  console.log('  ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝');
  console.log('');
  console.log(`  Your Private AI Empire is running at http://localhost:${PORT}`);
  console.log('');
});

syncMemoryToOpenClaw();
setInterval(syncMemoryToOpenClaw, 30_000);
