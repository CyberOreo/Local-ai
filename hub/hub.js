/**
 * LocalAI Hub Server
 * Serves the unified portal at http://localhost:8080
 * No npm dependencies - uses Node.js built-ins only (requires Node 18+)
 */

const http = require('http');
const fs   = require('fs');
const path = require('path');

const PORT     = 8080;
const HUB_DIR  = __dirname;
const HOME_DIR = process.env.USERPROFILE || process.env.HOME || '';

const MEMORY_JSON = path.join(HOME_DIR, '.clawbot_memory.json');
const OPENCLAW_WORKSPACE = path.join(HOME_DIR, '.openclaw', 'workspace');
const OPENCLAW_MEMORY_MD = path.join(OPENCLAW_WORKSPACE, 'MEMORY.md');

// ── Helpers ────────────────────────────────────────────────────────────────

async function ping(url, timeoutMs = 2000) {
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    const res = await fetch(url, { signal: ctrl.signal });
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

/**
 * Syncs ~/.clawbot_memory.json → ~/.openclaw/workspace/MEMORY.md
 * so Clawbot always knows everything the Local AI chat has remembered.
 */
function syncMemoryToOpenClaw() {
  try {
    const data  = readMemory();
    const facts = data.facts || [];
    if (facts.length === 0) return;

    // Group by category
    const groups = {};
    for (const f of facts) {
      const cat = (f.category || 'general')
        .replace(/_/g, ' ')
        .replace(/\b\w/g, c => c.toUpperCase());
      if (!groups[cat]) groups[cat] = [];
      groups[cat].push(f.fact);
    }

    let md = '# User Memory\n';
    md += '_Auto-synced from LocalAI Hub. Do not edit manually._\n\n';
    for (const [cat, items] of Object.entries(groups)) {
      md += `## ${cat}\n`;
      for (const item of items) md += `- ${item}\n`;
      md += '\n';
    }

    if (!fs.existsSync(OPENCLAW_WORKSPACE)) {
      fs.mkdirSync(OPENCLAW_WORKSPACE, { recursive: true });
    }
    fs.writeFileSync(OPENCLAW_MEMORY_MD, md, 'utf8');
  } catch {
    // Non-critical — silent fail
  }
}

// ── Request handler ────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  const url = req.url.split('?')[0];

  // Serve hub page
  if (url === '/' || url === '/index.html') {
    try {
      const html = fs.readFileSync(path.join(HUB_DIR, 'index.html'), 'utf8');
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
    } catch {
      res.writeHead(500);
      res.end('Hub page not found. Reinstall LocalAI Hub.');
    }
    return;
  }

  // Service status check
  if (url === '/api/status') {
    const [ollama, webui, openclaw] = await Promise.all([
      ping('http://localhost:11434/api/tags'),
      ping('http://localhost:3000'),
      ping('http://localhost:18789'),
    ]);
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache',
    });
    res.end(JSON.stringify({ ollama, webui, openclaw }));
    return;
  }

  // Memory read
  if (url === '/api/memory') {
    const data = readMemory();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(data));
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

// ── Start ──────────────────────────────────────────────────────────────────

server.listen(PORT, '127.0.0.1', () => {
  console.log('');
  console.log('  LocalAI Hub is running!');
  console.log(`  Open your browser: http://localhost:${PORT}`);
  console.log('');
  console.log('  Services expected at:');
  console.log('    Local AI Chat : http://localhost:3000');
  console.log('    Clawbot Agent : http://localhost:18789/webchat');
  console.log('    Ollama        : http://localhost:11434');
  console.log('');
  console.log('  Press Ctrl+C to stop the hub (other services keep running).');
  console.log('');
});

// Sync memory on startup then every 30 seconds
syncMemoryToOpenClaw();
setInterval(syncMemoryToOpenClaw, 30_000);
