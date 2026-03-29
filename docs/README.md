# Local AI — One-Click Windows 10 AI App

A complete local AI setup for Windows 10 that runs **Qwen 2.5 8B** on your GPU with a clean web chat interface. One click to launch, zero command-line use after installation.

---

## What This Is

This project gives you a fully local, offline-capable AI chatbot running on your own PC using:

- **Ollama** — runs AI models locally using your NVIDIA GPU
- **Open WebUI** — a clean, dark-themed browser chat interface
- **Qwen 2.5 8B** — a powerful 8-billion parameter language model

Everything runs on your machine. No cloud, no subscriptions, no data sent anywhere.

---

## Your Hardware Profile

| Component | Spec | Notes |
|-----------|------|-------|
| CPU | Ryzen 5 3600X (6c/12t) | 10 threads used by default |
| GPU | GTX 1070 Ti 8GB VRAM | All model layers offloaded to GPU |
| RAM | 16 GB | Leaves ~13 GB free during use |
| Model | qwen3:8b Q4_K_M | ~4.5–6.5 GB VRAM depending on profile |

**Expected performance (max-performance profile):**
- Speed: ~20–30 tokens/second
- First response: 3–6 seconds
- Context window: 8192 tokens

---

## Requirements

Before installing, make sure you have:

1. **Windows 10** (version 1803 or later)
2. **NVIDIA GPU drivers** — latest recommended ([download](https://www.nvidia.com/drivers))
3. **Docker Desktop** — [download here](https://www.docker.com/products/docker-desktop/)
   - Must be running (whale icon in system tray) before launching
4. **~20 GB free disk space** (for models)
5. **Internet connection** (for first-time setup only)

---

## Installation (One Time Only)

1. **Install Docker Desktop** if you haven't already
   - Download from: https://www.docker.com/products/docker-desktop/
   - Run the installer, restart if prompted
   - Start Docker Desktop — wait for the whale icon in the system tray

2. **Right-click `install.bat`** → **Run as administrator**

3. Wait — the installer will:
   - Check your system
   - Download and install Ollama (~50 MB)
   - Download Qwen 2.5 8B model (~5 GB) — **this takes 10–20 min**
   - Download Qwen 2.5 3B backup model (~2 GB)
   - Set up the Open WebUI container
   - Create a "Local AI" desktop shortcut

4. When complete, your browser will open to `http://localhost:3000`

---

## Daily Use

```
Double-click "Local AI" on your desktop
         ↓
Wait ~15–30 seconds (services start)
         ↓
Browser opens at http://localhost:3000
         ↓
Start chatting!
```

That's it. No terminal. No commands.

---

## Switching Performance Profiles

Edit the file `config\.env` and change the `PROFILE=` line:

| Profile | Context | GPU | Speed | Use When |
|---------|---------|-----|-------|----------|
| `max-performance` | 8192 tokens | ~88% | 20–30 tok/s | Default — best AI speed |
| `balanced` | 4096 tokens | ~70% | 20–28 tok/s | Running other heavy apps |
| `safe-mode` | 2048 tokens | ~50% | 15–20 tok/s | System feels sluggish |

```
# In config\.env:
PROFILE=max-performance    ← change this line
```

Then restart: double-click `launcher\restart-ai.bat`

---

## Switching Models

In Open WebUI, use the **model selector** at the top of the chat to switch between:

- `qwen3:8b` — full 8B model (best quality)
- `qwen3:8b-maxperf` — 8B with max-performance settings
- `qwen3:8b-balanced` — 8B with balanced settings
- `qwen3:8b-safe` — 8B with safe-mode settings
- `qwen3:4b` — smaller, faster backup model
- `qwen3:4b-fast` — 3B with max performance settings

---

## Stopping the App

**Option A:** Run `launcher\stop-ai.bat`

**Option B:** Docker Desktop tray → stop the `open-webui` container, and close Ollama from the system tray

The services run silently in the background. Closing the launcher window does NOT stop them.

---

## Updating Models

Run `scripts\update-model.bat` to download the latest model versions.
Requires internet. All other features still work offline.

---

## Enabling File Upload / RAG

Open WebUI has built-in RAG (document Q&A) support. To enable:

1. Go to `http://localhost:3000`
2. Click your profile icon (top right) → **Settings**
3. Go to **Documents**
4. Upload any PDF, TXT, or DOCX
5. In the chat, use `#document-name` to reference it

---

## Uninstalling

Run `scripts\uninstall.bat` — it will:
- Stop and remove the Open WebUI container
- Optionally remove chat history
- Optionally remove Ollama models
- Remove the desktop shortcut

To fully remove Ollama: **Windows Settings → Apps → Ollama → Uninstall**

---

## File Structure

```
LocalAI\
├── install.bat            ← Run once to install everything
├── install.ps1            ← Installer logic
├── launcher\
│   ├── launch-ai.bat      ← Daily one-click launcher
│   ├── stop-ai.bat        ← Stop all services
│   ├── restart-ai.bat     ← Restart all services
│   └── healthcheck.bat    ← Check if everything is working
├── scripts\
│   ├── update-model.bat   ← Update models to latest versions
│   ├── uninstall.bat      ← Remove everything
│   └── create-shortcut.ps1
├── config\
│   ├── .env               ← Your active settings (edit this)
│   ├── .env.example       ← Template
│   ├── settings.json      ← Ports, model names
│   └── profiles\          ← Performance profiles
├── logs\                  ← Log files
├── docs\
│   ├── README.md          ← This file
│   └── TROUBLESHOOTING.md
└── assets\                ← Icon files
```

---

## Local URLs

| Service | URL |
|---------|-----|
| Chat Interface | http://localhost:3000 |
| Ollama API | http://localhost:11434 |
| Ollama models list | http://localhost:11434/api/tags |

---

## Privacy

- Everything runs **100% locally** after setup
- No data is ever sent to external servers
- Chat history is stored locally in a Docker volume
- Models are stored in `%USERPROFILE%\.ollama\models`
