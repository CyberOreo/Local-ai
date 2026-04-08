# NeuralBox Security Policy

## Network Binding

All NeuralBox services bind exclusively to `127.0.0.1` (localhost):

| Service | Bind address | Port |
|---------|-------------|------|
| NeuralBox Hub | `127.0.0.1` | 8080 |
| Open WebUI (Docker) | `127.0.0.1` | 3000 |
| Update Server | `localhost` | 9999 |
| Ollama | (Ollama default) | 11434 |
| OpenClaw (optional) | `localhost` | 18789 |

None of these are reachable from other machines on your network by default.

The Open WebUI Docker container port binding is enforced at every launch:
- `docker run -p 127.0.0.1:3000:8080` — never `0.0.0.0:3000:8080`
- Both `install.ps1` and `launch-ai.bat` detect and recreate existing containers that were created with an insecure `0.0.0.0` binding.

## Hub Authentication

The NeuralBox Hub (`hub.js`) uses a two-layer auth model for privileged write endpoints:

### Layer 1 — CORS / Origin check
All POST, PUT, and DELETE requests must originate from `http://localhost:8080` or `http://127.0.0.1:8080`. Requests from any other Origin receive HTTP 403.

### Layer 2 — Session token
A cryptographically random 32-byte hex token is generated when the hub starts and stored in `~\.neuralbox\hub-token` (mode 0600). Privileged endpoints require this token via:
- **Browser**: `nb_session` HttpOnly cookie set automatically when the hub page is loaded (`GET /`)
- **Scripts / CLI**: `X-Hub-Token: <token>` header, or `Authorization: Bearer <token>`

Both layers must pass for write requests from browser contexts. CLI requests (no `Origin` header) require the token header alone.

**Protected endpoints** (require token):
- `POST /api/settings`
- `POST /api/keys/test`
- `POST /api/generate`
- `POST /api/worker/start`
- `POST /api/history/save`
- `DELETE /api/history/:id`
- `POST /api/history/:id/favorite`

**Unprotected read endpoints** (no token needed):
- `GET /api/status`, `/api/stats`, `/api/settings`, `/api/history`, `/api/templates`, `/api/profiles`

**Update Server proxy architecture**: The Update Server (`update-server.ps1`) is never called directly by the browser or Open WebUI tool. All update calls go through the NeuralBox Hub (`hub.js`), which acts as the authenticated gateway:

- Open WebUI tool (`webui-update-tool.py`) calls `http://host.docker.internal:8080/api/updater/*`
- Hub validates the hub session token, then proxies the request to `localhost:9999` with `X-Hub-Token` automatically
- The Update Server also validates the hub token on its own write endpoints (`/api/update`, `/api/reset`) as defense-in-depth

This means update triggers require valid authentication at **both** the hub layer and the update server layer. Direct requests to port 9999 without a valid hub token are rejected.

**Protected update endpoints** (require local origin + hub token):
- `POST /api/update` — starts background update job
- `POST /api/reset` — resets status to idle

**Unprotected update endpoints** (read-only, no auth):
- `GET /api/health` — liveness check
- `GET /api/status` — update progress (read-only)

## API Key Storage

- API keys are stored **encrypted** using Windows DPAPI (`ProtectedData.Protect`, `CurrentUser` scope) in `~\.neuralbox\settings.json`
- DPAPI-encrypted values are only decryptable by the same Windows user account on the same machine
- Keys are **never** stored in the project directory (which may be git-tracked)
- Legacy plaintext keys are automatically migrated to DPAPI-encrypted form on first load
- If DPAPI encryption fails on Windows, the key is **not saved** (error returned to caller — no silent plaintext fallback)
- If DPAPI decryption fails (e.g. key created by different user), the key is treated as unavailable (`null`) — the user is prompted to re-enter it
- The UI masks keys — only the last 4 characters are visible
- Keys are never printed to logs or console output

## Docker Image Pinning

The WebUI Docker image is configured in `_engine/version.json` under `webui_image`. All scripts (`install.ps1`, `launch-ai.bat`, `update-logic.ps1`, `app/main.js`) read from this single source. Changing the tag in `version.json` propagates everywhere.

For production use, pin to a specific version tag or digest:
```json
"webui_image": "ghcr.io/open-webui/open-webui:v0.6.5"
```

## Budget Controls

Budget limits are enforced server-side in `hub.js` and `efficiency.js`:

- `daily_limit_usd` — all API calls blocked once daily cap is reached
- `per_worker_budget_usd` — each worker job has a hard per-job cap; overflow falls back to local model
- `premium_calls_per_day` — counted server-side in `~\.neuralbox\spend.json`; blocked when limit reached
- `ask_before_expensive` — hub returns `{confirmation_required: true}` before any paid API call if enabled

The UI always reflects backend truth. Budget state is not trusted from the client.

## Open WebUI Auth

`WEBUI_AUTH=False` is set for local-only convenience. Because the container port is bound to `127.0.0.1`, external access is not possible under default configuration.

For multi-user setups on the same machine, remove `WEBUI_AUTH=False` from the `docker run` command and restart the container.

## Startup / Stop Determinism

- `start.bat` uses a single `config\.installed` flag file as the install detector. No multi-condition inference.
- The flag is written by `install.ps1` only on successful completion.
- `stop-ai.bat` verifies each service actually stopped; reports errors if a process survives the kill.

## Reporting a Vulnerability

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email the maintainer with: description, reproduction steps, and potential impact

We aim to acknowledge within 72 hours and release a fix within 14 days for critical issues.

## In Scope

- Hub session token bypass
- CORS / origin guard bypass (DNS rebinding, header injection)
- DPAPI migration or key exposure bugs
- Docker port exposure to non-localhost
- Budget enforcement bypass

## Out of Scope

- Vulnerabilities in Ollama, Docker, Open WebUI, or OpenClaw (report to those projects)
- Physical access attacks
- Social engineering
