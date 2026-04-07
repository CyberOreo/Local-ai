/**
 * NeuralBox — Storage Module
 * File-based persistence at ~/.neuralbox/
 * No external dependencies — Node.js built-ins only.
 */

'use strict';

const fs            = require('fs');
const path          = require('path');
const os            = require('os');
const { execSync }  = require('child_process');

// ── DPAPI secure key storage (Windows only) ───────────────────────────────────
// Keys stored as "dpapi:<base64>" in the settings file.
// Non-Windows: keys remain plaintext (user is responsible).

const DPAPI_PREFIX = 'dpapi:';

function dpapiEncrypt(plaintext) {
  if (process.platform !== 'win32' || !plaintext) return plaintext;
  try {
    const escaped = plaintext.replace(/'/g, "''");
    const script  = `[Convert]::ToBase64String([System.Security.Cryptography.ProtectedData]::Protect([System.Text.Encoding]::UTF8.GetBytes('${escaped}'), $null, 'CurrentUser'))`;
    const b64 = execSync(`powershell -NoProfile -Command "${script}"`, { timeout: 5000, stdio: ['ignore','pipe','ignore'] }).toString().trim();
    return DPAPI_PREFIX + b64;
  } catch {
    return plaintext; // fallback: store as-is
  }
}

function dpapiDecrypt(stored) {
  if (!stored || !stored.startsWith(DPAPI_PREFIX)) return stored;
  if (process.platform !== 'win32') return ''; // cannot decrypt on non-Windows
  try {
    const b64 = stored.slice(DPAPI_PREFIX.length);
    const script = `[System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String('${b64}'), $null, 'CurrentUser'))`;
    return execSync(`powershell -NoProfile -Command "${script}"`, { timeout: 5000, stdio: ['ignore','pipe','ignore'] }).toString().trim();
  } catch {
    return ''; // decryption failed — key lost/migrated
  }
}

function encryptApiKeys(api_keys) {
  if (!api_keys) return {};
  const out = {};
  for (const [provider, key] of Object.entries(api_keys)) {
    if (!key) { out[provider] = ''; continue; }
    // Only encrypt if not already encrypted
    out[provider] = key.startsWith(DPAPI_PREFIX) ? key : dpapiEncrypt(key);
  }
  return out;
}

function decryptApiKeys(api_keys) {
  if (!api_keys) return {};
  const out = {};
  for (const [provider, key] of Object.entries(api_keys)) {
    out[provider] = key && key.startsWith(DPAPI_PREFIX) ? dpapiDecrypt(key) : (key || '');
  }
  return out;
}

const NEURALBOX_DIR = path.join(os.homedir(), '.neuralbox');
const HISTORY_FILE  = path.join(NEURALBOX_DIR, 'history.json');
const SETTINGS_FILE = path.join(NEURALBOX_DIR, 'settings.json');
const SPEND_FILE    = path.join(NEURALBOX_DIR, 'spend.json');

// ── Helpers ───────────────────────────────────────────────────────────────────

function ensureDir() {
  if (!fs.existsSync(NEURALBOX_DIR)) {
    fs.mkdirSync(NEURALBOX_DIR, { recursive: true });
  }
}

function readJSON(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function writeJSON(file, data) {
  ensureDir();
  fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
}

function today() {
  return new Date().toISOString().slice(0, 10); // YYYY-MM-DD
}

// ── Default settings (merged with user overrides) ─────────────────────────────

const DEFAULT_SETTINGS = {
  project_name:           'NeuralBox',
  primary_model:          'qwen3.5:9b',
  backup_model:           'qwen3.5:4b',
  ollama_port:            11434,
  webui_port:             3000,
  default_profile:        'Balanced',
  daily_limit_usd:        1.00,
  per_worker_budget_usd:  0.10,
  premium_calls_per_day:  5,
  ask_before_expensive:   true,
  routing_rules: {
    templates:   'Local Only',
    workers:     'Balanced',
    money_mode:  'Balanced',
  },
  api_keys: {
    openai:    '',
    anthropic: '',
    groq:      '',
  },
  first_run_done: false,
};

// ── Settings ──────────────────────────────────────────────────────────────────

function loadUserSettings() {
  // Migrate plaintext keys on first load
  migrateKeysIfNeeded(SETTINGS_FILE);

  // Load project defaults from config/settings.json
  let projectDefaults = {};
  try {
    const configPath = path.join(__dirname, '..', 'config', 'settings.json');
    projectDefaults = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch { /* use built-in defaults */ }

  // Load user overrides from ~/.neuralbox/settings.json
  const userOverrides = readJSON(SETTINGS_FILE, {});

  // Merge: DEFAULT_SETTINGS → projectDefaults → userOverrides
  const merged = Object.assign({}, DEFAULT_SETTINGS, projectDefaults, userOverrides);

  // Deep merge routing_rules
  merged.routing_rules = Object.assign(
    {}, DEFAULT_SETTINGS.routing_rules,
    projectDefaults.routing_rules || {},
    userOverrides.routing_rules   || {}
  );

  // Deep merge api_keys then DECRYPT for in-memory use
  const rawKeys = Object.assign(
    {}, DEFAULT_SETTINGS.api_keys,
    projectDefaults.api_keys || {},
    userOverrides.api_keys   || {}
  );
  merged.api_keys = decryptApiKeys(rawKeys);

  return merged;
}

function saveUserSettings(patch) {
  const current = readJSON(SETTINGS_FILE, {});
  const updated  = Object.assign({}, current, patch);

  // Deep merge nested objects
  if (patch.routing_rules) {
    updated.routing_rules = Object.assign({}, current.routing_rules || {}, patch.routing_rules);
  }
  if (patch.api_keys) {
    const merged = Object.assign({}, current.api_keys || {}, patch.api_keys);
    // Encrypt any plaintext keys before persisting
    updated.api_keys = encryptApiKeys(merged);
  }

  writeJSON(SETTINGS_FILE, updated);
  return loadUserSettings(); // return full merged result
}

// Migrate any existing plaintext keys to DPAPI on first load
function migrateKeysIfNeeded(settingsFile) {
  if (process.platform !== 'win32') return;
  try {
    const data = readJSON(settingsFile, null);
    if (!data || !data.api_keys) return;
    let changed = false;
    const encrypted = {};
    for (const [provider, key] of Object.entries(data.api_keys)) {
      if (key && !key.startsWith(DPAPI_PREFIX)) {
        encrypted[provider] = dpapiEncrypt(key);
        changed = true;
      } else {
        encrypted[provider] = key;
      }
    }
    if (changed) {
      data.api_keys = encrypted;
      writeJSON(settingsFile, data);
    }
  } catch { /* non-critical */ }
}

// Mask API key for UI display — show only last 4 chars
function maskKey(key) {
  if (!key || key.length < 8) return '';
  return '•'.repeat(key.length - 4) + key.slice(-4);
}

function settingsForUI(settings) {
  const safe = Object.assign({}, settings);
  safe.api_keys = {};
  for (const [provider, key] of Object.entries(settings.api_keys || {})) {
    safe.api_keys[provider] = { masked: maskKey(key), has_key: !!(key && key.trim()) };
  }
  return safe;
}

// ── History ───────────────────────────────────────────────────────────────────

function loadHistory() {
  return readJSON(HISTORY_FILE, []);
}

function saveOutput(item) {
  const history = loadHistory();
  const entry   = Object.assign({
    id:        `nb_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    created_at: new Date().toISOString(),
    favorite:  false,
  }, item);

  history.unshift(entry); // newest first

  // Keep last 500 entries
  if (history.length > 500) history.length = 500;

  writeJSON(HISTORY_FILE, history);
  return entry;
}

function deleteOutput(id) {
  const history = loadHistory().filter(h => h.id !== id);
  writeJSON(HISTORY_FILE, history);
}

function toggleFavorite(id) {
  const history = loadHistory();
  const item = history.find(h => h.id === id);
  if (item) {
    item.favorite = !item.favorite;
    writeJSON(HISTORY_FILE, history);
    return item.favorite;
  }
  return false;
}

// ── Spend tracking ────────────────────────────────────────────────────────────

function loadSpend() {
  const data = readJSON(SPEND_FILE, {});
  const d    = today();

  // Clean up entries older than 30 days
  const keys = Object.keys(data).filter(k => k < d);
  if (keys.length > 30) {
    for (const k of keys.slice(0, keys.length - 30)) delete data[k];
    writeJSON(SPEND_FILE, data);
  }

  return data;
}

function trackSpend(usdAmount, costLabel) {
  if (!usdAmount || usdAmount <= 0) return;
  const data    = loadSpend();
  const d       = today();
  data[d]       = (data[d] || 0) + usdAmount;
  // Track premium calls separately for per-day limit enforcement
  if (costLabel && costLabel !== 'Free') {
    const key = `${d}_premium_calls`;
    data[key] = (data[key] || 0) + 1;
  }
  writeJSON(SPEND_FILE, data);
}

function getSpend(settings) {
  const data        = loadSpend();
  const d           = today();
  const today_usd   = data[d] || 0;
  const daily_limit = (settings && settings.daily_limit_usd) || 1.00;
  const pct_used    = daily_limit > 0 ? today_usd / daily_limit : 0;

  // Session spend: sum of all entries in current data (approximate)
  const session_usd = Object.values(data).reduce((a, v) => a + v, 0);

  return {
    today_usd:   parseFloat(today_usd.toFixed(6)),
    session_usd: parseFloat(session_usd.toFixed(6)),
    limit_usd:   daily_limit,
    pct_used:    parseFloat(Math.min(pct_used, 1).toFixed(4)),
    locked:      today_usd >= daily_limit,
    warning:     pct_used >= 0.80 && pct_used < 1.0,
  };
}

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = {
  loadUserSettings,
  saveUserSettings,
  settingsForUI,
  loadHistory,
  saveOutput,
  deleteOutput,
  toggleFavorite,
  trackSpend,
  getSpend,
  loadSpend,
  NEURALBOX_DIR,
};
