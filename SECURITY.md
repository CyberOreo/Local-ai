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

## CORS Protection

The NeuralBox Hub (`hub.js`) enforces strict CORS:
- Only `http://localhost:8080` and `http://127.0.0.1:8080` are allowed as request origins
- All write endpoints (`POST /api/settings`, `POST /api/keys/test`, `POST /api/worker/start`, etc.) reject requests from any other origin with HTTP 403
- The Update Server (`update-server.ps1`) similarly rejects non-local origins on write endpoints

## API Key Storage

- API keys are stored **encrypted** using Windows DPAPI (`ProtectedData.Protect`, `CurrentUser` scope) in `~\.neuralbox\settings.json`
- DPAPI-encrypted values are only decryptable by the same Windows user account on the same machine
- Keys are **never** stored in the project directory (which may be git-tracked)
- Legacy plaintext keys are automatically migrated to DPAPI-encrypted form on first load
- The UI masks keys — only the last 4 characters are visible
- Keys are never printed to logs or console output

## Open WebUI Auth

`WEBUI_AUTH=False` is set for local-only convenience. Because the container port is bound to `127.0.0.1`, external access is not possible under default configuration.

If you need multi-user access on the same machine, remove `WEBUI_AUTH=False` from the `docker run` command and restart the container.

## Budget Controls

The budget system enforces hard limits:
- `daily_limit_usd` — API calls are blocked once the daily cap is hit
- `per_worker_budget_usd` — each worker job is capped; excess falls back to local
- `premium_calls_per_day` — counted and enforced server-side

## Reporting a Vulnerability

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email the maintainer with: description, reproduction steps, and potential impact

We aim to acknowledge within 72 hours and release a fix within 14 days for critical issues.

## In Scope

- Cross-origin request bypass on hub or update server endpoints
- DPAPI migration or key exposure bugs
- Remote code execution via hub server endpoints
- Budget enforcement bypass

## Out of Scope

- Vulnerabilities in Ollama, Docker, Open WebUI, or OpenClaw (report to those projects)
- Physical access attacks
- Social engineering
