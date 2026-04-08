# NeuralBox — Local AI on Windows

Runs **Qwen 3.5 9B** locally via Ollama + Open WebUI + NeuralBox Hub.
One click to launch. No cloud, no subscriptions after setup.

---

## What Runs

| Service | URL | What it does |
|---------|-----|-------------|
| **NeuralBox Hub** | http://localhost:8080 | Main portal — money tools, templates, workers, history |
| **Open WebUI** | http://localhost:3000 | Full chat interface |
| **Ollama** | http://localhost:11434 | Local AI model server |
| **Update Server** | http://localhost:9999 | Handles in-app update requests (same runtime as batch) |
| **OpenClaw (optional)** | http://localhost:18789 | AI agent orchestration |

All services bind to **127.0.0.1 only**. Nothing is accessible from other machines.

---

## Requirements

1. **Windows 10/11**
2. **NVIDIA GPU drivers** ([download](https://www.nvidia.com/drivers))
3. **Docker Desktop** ([download](https://www.docker.com/products/docker-desktop/)) — must be running
4. **~20 GB free disk space**
5. **Internet** on first install only

---

## Installation (Once)

1. Install Docker Desktop, start it, wait for the whale icon in the tray
2. **Double-click `start.bat`** — it detects first run and calls the installer automatically
   - You will see a UAC (admin) prompt — click **Yes**
3. The installer will:
   - Check your system (RAM, GPU, disk)
   - Download and install Ollama
   - Download **qwen3.5:9b** (~6.6 GB) and **qwen3.5:4b** (~2.5 GB)
   - Create the Open WebUI Docker container (bound to 127.0.0.1:3000)
   - Create a "NeuralBox" desktop shortcut
   - Write `config\.installed` on success
4. NeuralBox launches automatically when done

> To reinstall: delete `config\.installed` and run `start.bat` again.

---

## Daily Use

```
Double-click  start.bat  (or the Desktop shortcut)
       ↓
Reads config\.installed — goes straight to launch
       ↓
Starts: Ollama → Docker/WebUI → Hub → Update Server → OpenClaw
       ↓
Browser opens at http://localhost:8080 (NeuralBox Hub)
```

---

## Startup Flow Detail

`start.bat` → `_engine\launcher\launch-ai.bat`:

1. Load `.env` profile (Ollama settings)
2. Read Docker image tag from `_engine\version.json`
3. Start / wait for **Ollama** (port 11434)
4. Start Docker Desktop if needed; wait for daemon
5. Check `open-webui` container:
   - If bound to `0.0.0.0` → stop, remove, recreate with `127.0.0.1`
   - If stopped → start it
   - If missing → create with correct binding
6. Wait for **Open WebUI** (port 3000)
7. Start **Update Server** (port 9999)
8. Start **OpenClaw** if installed (port 18789)
9. Start **NeuralBox Hub** via Node.js (port 8080)
10. Open browser

The Electron app (`app/main.js`) runs the same startup sequence including the update server.

---

## Stopping

Run `_engine\launcher\stop-ai.bat`

Stops: Hub, Open WebUI container, Ollama, Update Server, OpenClaw.
Verifies each service actually stopped; reports failures.

---

## Restarting

Run `_engine\launcher\restart-ai.bat`

---

## Health Check

Run `_engine\launcher\healthcheck.bat`

Shows pass/fail for every service.

---

## Smoke Test

Run `_engine\scripts\smoke-test.bat`

Validates: file structure, prerequisites, service health, API endpoints,
CORS + token auth, Docker port binding, budget fields, stop flow, path resolution.

---

## Performance Profiles

Edit `config\.env` → change `PROFILE=`:

| Profile | Context | GPU | Speed |
|---------|---------|-----|-------|
| `max-performance` | 4096 tok | 36 layers | 18–25 tok/s |
| `balanced` | 2048 tok | 36 layers | 20–27 tok/s |
| `quality` | 6144 tok | 36 layers | 15–20 tok/s |
| `safe-mode` | 1024 tok | 20 layers | 10–15 tok/s |

After changing: run `_engine\launcher\restart-ai.bat`

---

## API Keys (Optional)

Open **NeuralBox Hub → Settings → API Keys** to add OpenAI, Anthropic, or Groq keys.

Keys are stored **DPAPI-encrypted** at `~\.neuralbox\settings.json` — never in the project directory.
If DPAPI encryption fails, the key is rejected (not stored as plaintext).

---

## Hub Authentication

The Hub uses session-token auth for all write endpoints:

- **Browser**: Load `http://localhost:8080` — an `nb_session` cookie is set automatically.
  All subsequent API calls from the page include the cookie.
- **Scripts / CLI**: Read the token from `~\.neuralbox\hub-token`, then pass it as:
  `X-Hub-Token: <token>` or `Authorization: Bearer <token>`

---

## Budget Controls

Configure in Hub → Settings → Budget:

- **Daily limit (USD)** — API calls blocked once reached
- **Per-worker cap (USD)** — hard limit per worker job; overflow falls back to local model
- **Premium calls/day** — counted server-side; blocked when limit reached
- **Ask before expensive** — hub prompts for confirmation before any paid API call

All limits are enforced by the backend — UI warnings are informational only.

---

## Docker Image Version

The WebUI Docker image is configured in `_engine\version.json`:

```json
"webui_image": "ghcr.io/open-webui/open-webui:main"
```

To pin to a specific version (recommended for production):
```json
"webui_image": "ghcr.io/open-webui/open-webui:v0.6.5"
```

All scripts read from this one location. Changing it here changes it everywhere.

---

## Updating

- **In-app**: use the Update button in Hub, or type `update` in Open WebUI chat
- **Manual**: run `_engine\update.bat`

Update logic (`update-logic.ps1`) reads model names and Docker image from `_engine\version.json`.

---

## File Structure

```
Local-ai\
├── start.bat                    ← Entry point: install or launch
├── config\
│   ├── .installed               ← Written by installer; deleted = triggers reinstall
│   ├── .env                     ← Active settings (edit this)
│   ├── .env.example             ← Template
│   ├── settings.json            ← Ports, models, budget defaults
│   └── profiles\                ← Performance profiles
├── hub\
│   ├── hub.js                   ← NeuralBox Hub server (port 8080) + token auth
│   ├── index.html               ← Hub UI
│   ├── storage.js               ← File-based persistence + key encryption
│   ├── keystore.js              ← Windows DPAPI key encryption (no plaintext fallback)
│   ├── efficiency.js            ← Stage-based generation + full budget enforcement
│   ├── router.js                ← Model routing + budget checks
│   └── templates.js             ← Money tools + template definitions
├── app\
│   └── main.js                  ← Electron wrapper (same startup as batch)
├── _engine\
│   ├── install.bat              ← Installer entry (handles own elevation)
│   ├── install.ps1              ← Installer logic; writes config\.installed on success
│   ├── version.json             ← Single source for Docker image + model versions
│   ├── launcher\
│   │   ├── launch-ai.bat        ← Start all services
│   │   ├── stop-ai.bat          ← Stop all services (verified)
│   │   ├── restart-ai.bat       ← Restart all services
│   │   └── healthcheck.bat      ← Check all services
│   ├── scripts\
│   │   ├── update-server.ps1    ← HTTP server for update triggers (origin-checked)
│   │   ├── update-logic.ps1     ← Actual update execution (reads version.json)
│   │   ├── create-shortcut.ps1  ← Desktop shortcut creator
│   │   ├── smoke-test.bat       ← Full smoke test suite
│   │   └── update-model.bat     ← Update models only
│   └── docs\
│       ├── README.md            ← This file
│       └── TROUBLESHOOTING.md
└── logs\                        ← Log files (gitignored)
```

---

## Runtime Data (not in project dir)

| Path | What |
|------|------|
| `~\.neuralbox\settings.json` | User settings + DPAPI-encrypted API keys |
| `~\.neuralbox\hub-token` | Hub session token (0600 permissions) |
| `~\.neuralbox\history.json` | Generation history |
| `~\.neuralbox\spend.json` | Daily spend tracking |
| Docker volume `open-webui` | Open WebUI chat history |

---

## Privacy

Everything runs locally after setup.
**API keys are only sent to their respective providers** (OpenAI/Anthropic/Groq) if you configure them.
NeuralBox never phones home and does not collect usage data.
