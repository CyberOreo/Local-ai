'use strict';
// keystore.js — API key encryption using Windows DPAPI via PowerShell subprocess.
// On non-Windows, falls back to plaintext with a dpapi: prefix stripped.
// All values stored/returned have a 'dpapi:' prefix when encrypted.

const { execFileSync } = require('child_process');

const IS_WIN = process.platform === 'win32';
const PREFIX = 'dpapi:';

function encrypt(plaintext) {
  if (!IS_WIN || !plaintext) return plaintext;
  try {
    const script = [
      '$bytes = [System.Text.Encoding]::UTF8.GetBytes($args[0])',
      '$enc   = [System.Security.Cryptography.ProtectedData]::Protect($bytes,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser)',
      '[Convert]::ToBase64String($enc)',
    ].join(';');
    const b64 = execFileSync('powershell.exe', [
      '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-Command', script, plaintext,
    ], { timeout: 8000, encoding: 'utf8' }).trim();
    return PREFIX + b64;
  } catch {
    return plaintext; // non-fatal: store plaintext if DPAPI unavailable
  }
}

function decrypt(stored) {
  if (!stored) return stored;
  if (!stored.startsWith(PREFIX)) return stored; // already plaintext
  const b64 = stored.slice(PREFIX.length);
  if (!IS_WIN) return ''; // can't decrypt on non-Windows; treat as missing
  try {
    const script = [
      '$bytes = [Convert]::FromBase64String($args[0])',
      '$dec   = [System.Security.Cryptography.ProtectedData]::Unprotect($bytes,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser)',
      '[System.Text.Encoding]::UTF8.GetString($dec)',
    ].join(';');
    return execFileSync('powershell.exe', [
      '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-Command', script, b64,
    ], { timeout: 8000, encoding: 'utf8' }).trim();
  } catch {
    return '';
  }
}

function isEncrypted(val) {
  return typeof val === 'string' && val.startsWith(PREFIX);
}

module.exports = { encrypt, decrypt, isEncrypted };
