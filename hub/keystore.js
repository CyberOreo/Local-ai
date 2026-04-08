'use strict';
// keystore.js — API key encryption using Windows DPAPI via PowerShell subprocess.
//
// On Windows: keys are always encrypted with DPAPI (CurrentUser scope).
//   - encrypt() throws on failure — do NOT silently store plaintext.
//   - decrypt() returns null on failure — key unavailable, not empty.
// On non-Windows (dev/Linux): DPAPI unavailable.
//   - encrypt() returns plaintext with a console warning.
//   - decrypt() returns the plaintext if stored unencrypted, null if DPAPI-prefixed.
//
// Stored values have a 'dpapi:' prefix when encrypted.

const { execFileSync } = require('child_process');

const IS_WIN = process.platform === 'win32';
const PREFIX = 'dpapi:';

/**
 * Encrypt a plaintext API key.
 * - Windows: returns 'dpapi:<base64>'. Throws if DPAPI fails.
 * - Non-Windows: returns plaintext (with warning). Never throws.
 * @returns {string|null} encrypted value, or null if plaintext is empty/null
 */
function encrypt(plaintext) {
  if (!plaintext) return plaintext;

  if (!IS_WIN) {
    // Non-Windows: DPAPI not available. Store plaintext but warn.
    console.warn('[keystore] WARNING: DPAPI not available on non-Windows. Key stored unencrypted.');
    return plaintext;
  }

  // Already encrypted — don't double-encrypt
  if (isEncrypted(plaintext)) return plaintext;

  try {
    const script = [
      '$bytes = [System.Text.Encoding]::UTF8.GetBytes($args[0])',
      '$enc   = [System.Security.Cryptography.ProtectedData]::Protect(',
      '           $bytes, $null,',
      '           [System.Security.Cryptography.DataProtectionScope]::CurrentUser)',
      '[Convert]::ToBase64String($enc)',
    ].join(' ');
    const b64 = execFileSync('powershell.exe', [
      '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-Command', script, plaintext,
    ], { timeout: 8000, encoding: 'utf8' }).trim();
    if (!b64) throw new Error('DPAPI returned empty result');
    return PREFIX + b64;
  } catch (err) {
    // On Windows, encryption failure is a hard error. Do NOT fall back to plaintext.
    throw new Error(`DPAPI encryption failed: ${err.message}. API key not saved.`);
  }
}

/**
 * Decrypt a stored value.
 * - If not prefixed with 'dpapi:': returns as-is (plaintext or already decrypted).
 * - If prefixed and on Windows: decrypts and returns plaintext.
 * - If prefixed and on non-Windows: returns null (cannot decrypt).
 * - If DPAPI fails: returns null (key unavailable, not empty string).
 * @returns {string|null}
 */
function decrypt(stored) {
  if (!stored) return null;
  if (!stored.startsWith(PREFIX)) return stored; // plaintext (non-Windows or legacy)

  const b64 = stored.slice(PREFIX.length);

  if (!IS_WIN) {
    console.warn('[keystore] Cannot decrypt DPAPI-encrypted key on non-Windows.');
    return null;
  }

  try {
    const script = [
      '$bytes = [Convert]::FromBase64String($args[0])',
      '$dec   = [System.Security.Cryptography.ProtectedData]::Unprotect(',
      '           $bytes, $null,',
      '           [System.Security.Cryptography.DataProtectionScope]::CurrentUser)',
      '[System.Text.Encoding]::UTF8.GetString($dec)',
    ].join(' ');
    const plaintext = execFileSync('powershell.exe', [
      '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-Command', script, b64,
    ], { timeout: 8000, encoding: 'utf8' }).trim();
    return plaintext;
  } catch (err) {
    // Decryption failed: key was encrypted by a different user/machine, or DPAPI unavailable.
    // Return null — caller should treat as "key not available" and prompt user to re-enter.
    console.error(`[keystore] DPAPI decryption failed: ${err.message}`);
    return null;
  }
}

/** Returns true if value was encrypted with DPAPI by this module. */
function isEncrypted(val) {
  return typeof val === 'string' && val.startsWith(PREFIX);
}

module.exports = { encrypt, decrypt, isEncrypted };
