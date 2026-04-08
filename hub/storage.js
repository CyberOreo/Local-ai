/**
 * NeuralBox — Storage Module
 * File-based persistence at ~/.neuralbox/
 * No external dependencies — Node.js built-ins only.
 */

'use strict';

const fs   = require('fs');
const path = require('path');
const os   = require('os');
const ks   = require('./keystore');

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

// ── Default settings ──────────────────────────────────────────────────────────

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

// ── API key encryption helpers ────────────────────────────────────────────────

function encryptApiKeys(api_keys) {
  if (!api_keys) return {};
  const out = {};
  for (const [provider, key] of Object.entries(api_keys)) {
    if (!key) { out[provider] = ''; continue; }
    if (ks.isEncrypted(key)) { out[provider] = key; continue; }
    // ks.encrypt() throws on Windows DPAPI failure — let it propagate
    out[provider] = ks.encrypt(key);
  }
  return out;
}

function decryptApiKeys(api_keys) {
  if (!api_keys) return {};
  const out = {};
  for (const [provider, key] of Object.entries(api_keys)) {
    if (!key) { out[provider] = ''; continue; }
    const decrypted = ks.decrypt(key);
    // null = DPAPI unavailable or decryption failed → treat as missing (not empty string)
    out[provider] = decrypted ?? '';
  }
  return out;
}

// Auto-migrate any plaintext API keys on first load (Windows only).
// If encryption fails for a key, it's left plaintext and retried next load.
function migrateKeysIfNeeded(settingsFile) {
  if (process.platform !== 'win32') return;
  try {
    const data = readJSON(settingsFile, null);
    if (!data || !data.api_keys) return;
    let changed = false;
    const encrypted = {};
    for (const [provider, key] of Object.entries(data.api_keys)) {
      if (key && !ks.isEncrypted(key)) {
        try {
          encrypted[provider] = ks.encrypt(key);
          changed = true;
        } catch (e) {
          // Migration failed for this key — leave plaintext, log warning
          console.warn(`[storage] Could not encrypt ${provider} key during migration: ${e.message}`);
          encrypted[provider] = key;
        }
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

// ── Settings ──────────────────────────────────────────────────────────────────

function loadUserSettings() {
  migrateKeysIfNeeded(SETTINGS_FILE);

  let projectDefaults = {};
  try {
    const configPath = path.join(__dirname, '..', 'config', 'settings.json');
    projectDefaults = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch { /* use built-in defaults */ }

  const userOverrides = readJSON(SETTINGS_FILE, {});

  // Merge: DEFAULT_SETTINGS → projectDefaults → userOverrides
  const merged = Object.assign({}, DEFAULT_SETTINGS, projectDefaults, userOverrides);

  merged.routing_rules = Object.assign(
    {}, DEFAULT_SETTINGS.routing_rules,
    projectDefaults.routing_rules || {},
    userOverrides.routing_rules   || {}
  );

  // Merge api_keys and decrypt for in-memory use
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

  if (patch.routing_rules) {
    updated.routing_rules = Object.assign({}, current.routing_rules || {}, patch.routing_rules);
  }
  if (patch.api_keys) {
    const merged = Object.assign({}, current.api_keys || {}, patch.api_keys);
    updated.api_keys = encryptApiKeys(merged);
  }

  writeJSON(SETTINGS_FILE, updated);
  return loadUserSettings();
}

// Mask API key for UI display — show only last 4 chars
function maskKey(key) {
  if (!key || key.length < 8) return '';
  return '•'.repeat(Math.min(key.length - 4, 20)) + key.slice(-4);
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
    id:         `nb_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    created_at: new Date().toISOString(),
    favorite:   false,
  }, item);

  history.unshift(entry); // newest first
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
  const item    = history.find(h => h.id === id);
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

  // Purge entries older than 30 days (keep only date keys and their _premium_calls siblings)
  const allKeys = Object.keys(data);
  const oldDates = allKeys.filter(k => /^\d{4}-\d{2}-\d{2}$/.test(k) && k < d)
                          .sort().slice(0, -30);
  for (const k of oldDates) {
    delete data[k];
    delete data[`${k}_premium_calls`];
  }
  if (oldDates.length) writeJSON(SPEND_FILE, data);

  return data;
}

function trackSpend(usdAmount, costLabel) {
  const data = loadSpend();
  const d    = today();

  if (usdAmount && usdAmount > 0) {
    data[d] = (data[d] || 0) + usdAmount;
  }

  // Count non-free calls toward daily premium limit
  if (costLabel && costLabel !== 'Free') {
    const key  = `${d}_premium_calls`;
    data[key]  = (data[key] || 0) + 1;
  }

  writeJSON(SPEND_FILE, data);
}

function getSpend(settings) {
  const data             = loadSpend();
  const d                = today();
  const today_usd        = data[d] || 0;
  const premium_calls    = data[`${d}_premium_calls`] || 0;
  const daily_limit      = (settings && settings.daily_limit_usd)       || 1.00;
  const max_premium      = (settings && settings.premium_calls_per_day)  || 5;
  const pct_used         = daily_limit > 0 ? today_usd / daily_limit : 0;
  const calls_pct        = max_premium  > 0 ? premium_calls / max_premium : 0;

  return {
    today_usd:        parseFloat(today_usd.toFixed(6)),
    limit_usd:        daily_limit,
    pct_used:         parseFloat(Math.min(pct_used, 1).toFixed(4)),
    locked:           today_usd >= daily_limit,
    warning:          pct_used >= 0.80 && pct_used < 1.0,
    premium_calls:    premium_calls,
    max_premium:      max_premium,
    premium_locked:   premium_calls >= max_premium,
    premium_warning:  calls_pct >= 0.80 && calls_pct < 1.0,
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
