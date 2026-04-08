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
| **Update Server** | http://localhost:9999 | Handles in-app update requests |
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
2. **Right-click `_engine\install.bat`** → **Run as administrator**
3. Wait — the installer will:
   - Check your system (RAM, GPU, disk)
   - Download and install Ollama
   - Download **qwen3.5:9b** (~6.6 GB) and **qwen3.5:4b** (~2.5 GB)
   - Create the Open WebUI Docker container (bound to 127.0.0.1)
   - Create a "NeuralBox" desktop shortcut
4. NeuralBox launches automatically when done

---

## Daily Use

```
Double-click  start.bat  (or the Desktop shortcut)
       ↓
All services start automatically
       ↓
Browser opens at http://localhost:8080 (NeuralBox Hub)
```

---

## Stopping

Run `_engine\launcher\stop-ai.bat`

Stops: Hub, Open WebUI container, Ollama, Update Server, OpenClaw.

---

## Restarting

Run `_engine\launcher\restart-ai.bat`

---

## Health Check

Run `_engine\launcher\healthcheck.bat`

Shows pass/fail for every service including Hub, Update Server, and OpenClaw.

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

Keys are stored encrypted (DPAPI) at `~\.neuralbox\settings.json` — never in the project directory.

---

## Updating

- **In-app**: type `update` in Open WebUI chat, or use the Update button in Hub
- **Manual**: run `_engine\update.bat`

---

## File Structure

```
Local-ai\
├── start.bat                    ← Daily launcher (decides install or launch)
├── config\
│   ├── .env                     ← Active settings (edit this)
│   ├── .env.example             ← Template
│   ├── settings.json            ← Ports, models, budget defaults
│   └── profiles\                ← Performance profiles
├── hub\
│   ├── hub.js                   ← NeuralBox Hub server (port 8080)
│   ├── index.html               ← Hub UI
│   ├── storage.js               ← File-based persistence + key encryption
│   ├── keystore.js              ← Windows DPAPI key encryption helper
│   ├── efficiency.js            ← Stage-based generation + budget enforcement
│   ├── router.js                ← Model routing + budget checks
│   └── templates.js             ← Money tools + template definitions
├── app\
│   └── main.js                  ← Electron wrapper (optional desktop app)
├── _engine\
│   ├── install.bat              ← Run once to install
│   ├── install.ps1              ← Installer logic
│   ├── version.json             ← Pinned versions
│   ├── launcher\
│   │   ├── launch-ai.bat        ← Start all services
│   │   ├── stop-ai.bat          ← Stop all services
│   │   ├── restart-ai.bat       ← Restart all services
│   │   └── healthcheck.bat      ← Check all services
│   ├── scripts\
│   │   ├── update-server.ps1    ← HTTP server for update triggers
│   │   ├── update-logic.ps1     ← Actual update execution
│   │   ├── create-shortcut.ps1  ← Desktop shortcut creator
│   │   ├── uninstall.bat        ← Remove everything
│   │   ├── smoke-test.bat       ← Smoke test suite
│   │   └── update-model.bat     ← Update models only
│   └── docs\
│       ├── README.md            ← This file
│       └── TROUBLESHOOTING.md
└── logs\                        ← Log files (gitignored)
```

---

## Privacy

Everything runs locally after setup.
**API keys are only sent to their respective providers** (OpenAI/Anthropic/Groq) if you configure them.
NeuralBox never phones home and does not collect usage data.
