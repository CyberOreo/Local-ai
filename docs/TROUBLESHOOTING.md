# Troubleshooting Guide

## Quick Diagnosis

Before anything else, run:

```
launcher\healthcheck.bat
```

It tests all services and shows exactly what is and isn't working.

---

## Common Issues

---

### Launcher window closes instantly

**Symptom:** `launch-ai.bat` opens and immediately disappears.

**Fix:**
1. Open `logs\launch.log` in Notepad — the last line will show the error
2. Right-click `launch-ai.bat` → **Run as administrator** (some setups need this)
3. Alternatively: open a CMD window, drag `launch-ai.bat` into it, press Enter — error will stay visible

---

### Model is too slow / responses take a long time

**Symptom:** Responses take 30+ seconds, or typing appears very slowly.

**Fixes (try in order):**
1. **Check GPU is being used:** Open CMD and run `nvidia-smi` — look for `ollama` in the list with VRAM usage. If not showing, GPU is not being used.
2. **Switch to balanced profile:** Edit `config\.env` → set `PROFILE=balanced` → restart
3. **Switch to safe-mode profile:** Edit `config\.env` → set `PROFILE=safe-mode` → restart
4. **Use the backup model:** In Open WebUI model selector, choose `qwen3.5:4b` — it runs at ~50–70 tok/s
5. **Close other heavy apps** (games, browsers with many tabs, video editors) before launching

---

### Out of memory / app crashes

**Symptom:** Ollama crashes, Windows shows low memory warning, or the model fails to load.

**Fixes:**
1. Switch to `safe-mode` profile (in `config\.env`)
2. Use `qwen3.5:4b` instead of 8B
3. Reduce context: in `config\profiles\safe-mode.env` change `OLLAMA_NUM_CTX=1024`
4. Close Chrome/Edge tabs, other RAM-heavy apps
5. Restart your PC to free fragmented memory

---

### Browser doesn't open / Web UI not loading

**Symptom:** Launcher runs but browser doesn't open, or browser shows "This page can't be reached".

**Fixes:**
1. **Wait longer:** Open WebUI first start can take 60–90 seconds to initialize. Wait 2 minutes, then manually go to `http://localhost:3000`
2. **Check the container:** Open CMD and run `docker ps` — `open-webui` should be listed with status `Up`
3. **Check container logs:** Run `docker logs open-webui` to see any error messages
4. **Restart the container:** Run `docker restart open-webui` then wait 30 seconds
5. **Port conflict:** Another app might be using port 3000. Check with `netstat -aon | findstr :3000`. If occupied, change `WEBUI_PORT=3001` in `config\.env` and re-run the installer.

---

### Ollama not running / "connection refused" on port 11434

**Symptom:** Healthcheck shows Ollama FAIL, or Open WebUI shows "Ollama connection failed".

**Fixes:**
1. Run `launcher\launch-ai.bat` — it will start Ollama automatically
2. Check if Ollama is installed: open CMD, type `ollama --version`
3. If Ollama is installed but won't start: check Windows Defender/antivirus — it may be blocking `ollama.exe`
4. Add Ollama to antivirus exclusions: usually under Settings → Virus & Threat Protection → Exclusions
5. Run `ollama serve` manually in CMD to see the error message

---

### Open WebUI not connecting to Ollama

**Symptom:** Open WebUI loads but shows "Ollama not connected" or no models appear.

**Fixes:**
1. Confirm Ollama is running: run `curl http://localhost:11434` in CMD — should return text
2. Confirm the container has the right env var: run `docker inspect open-webui | findstr OLLAMA_BASE_URL`
   - It should show `http://host.docker.internal:11434`
3. If the URL is wrong, remove and recreate the container:
   ```
   docker stop open-webui
   docker rm open-webui
   ```
   Then run `launcher\launch-ai.bat` (it will recreate the container with correct settings)

---

### Port conflict on 11434 or 3000

**Symptom:** Error "port already in use" or services don't start.

**Fix:**
1. Find what's using the port: `netstat -aon | findstr :11434`
2. Note the PID and check in Task Manager
3. If you want to use a different port, edit `config\.env`:
   ```
   OLLAMA_PORT=11435
   WEBUI_PORT=3001
   ```
4. Re-run `install.bat` to recreate the container with the new port

---

### GPU not being used (CPU-only mode)

**Symptom:** `nvidia-smi` shows Ollama not listed, responses are very slow (2–5 tok/s).

**Fixes:**
1. **Update NVIDIA drivers** — download from https://www.nvidia.com/drivers
2. **Reinstall Ollama** — uninstall via Windows Settings, then re-run `install.bat`
3. **Check CUDA is available:** Run `ollama run qwen3.5:8b "hello"` in CMD. If it says "CUDA not available" or "using CPU", that confirms the issue.
4. **Check GPU is detected by Ollama:** Run `ollama ps` after starting a model — it should show `GPU` layers

---

### Docker Desktop won't start

**Symptom:** Docker Desktop opens but shows errors, or the daemon never starts.

**Fixes:**
1. **Restart Docker Desktop:** Right-click the whale in the system tray → Restart
2. **Restart your PC** — sometimes a full reboot fixes Docker initialization issues
3. **Check Hyper-V / WSL2:** Docker Desktop requires one of these. Open "Turn Windows features on or off" and make sure "Hyper-V" or "Windows Subsystem for Linux" is enabled
4. **Reinstall Docker Desktop** if all else fails — your `open-webui` container and data will survive if you don't delete volumes

---

### Windows permissions issue

**Symptom:** Scripts fail with "Access denied", "requires administrator", or similar.

**Fix:**
- Always right-click `install.bat` → **Run as administrator**
- For the launcher, you typically do NOT need admin. If you do, right-click `launch-ai.bat` → Run as administrator

---

### "Could not find docker command" during install

**Symptom:** Installer says Docker is not found even after installing Docker Desktop.

**Fixes:**
1. Make sure Docker Desktop is fully started (whale icon in tray, not spinning)
2. Try restarting the install: the installer waits for you to press Enter after Docker is ready
3. Open a new CMD window and type `docker --version` — if it works there, the PATH just needs a refresh (close and reopen the installer window)

---

### Chat history disappeared

**Symptom:** All previous conversations are gone.

**Causes and fixes:**
- If you ran `scripts\uninstall.bat` and removed the volume — the data is permanently deleted
- If the container was recreated (removed and re-created), data is preserved in the `open-webui` Docker volume
- To check if the volume exists: `docker volume ls | findstr open-webui`

---

### "This model is too large" or VRAM errors

**Symptom:** Model fails to load, error mentions memory.

**Fixes:**
1. Switch to `safe-mode` profile and try again
2. Use `qwen3.5:4b` (much smaller, fits easily)
3. Run `nvidia-smi` to check actual free VRAM before loading
4. Stop other GPU-using applications (games, rendering apps)

---

## Log Files

| File | What It Contains |
|------|-----------------|
| `logs\install.log` | Installation steps and any errors |
| `logs\launch.log` | Launcher events and timestamps |
| `logs\update.log` | Model update history |

Docker container logs: `docker logs open-webui`

---

## Getting More Help

1. Run `launcher\healthcheck.bat` and note exactly which checks fail
2. Check the relevant section above
3. Check Ollama docs: https://ollama.com/docs
4. Check Open WebUI docs: https://docs.openwebui.com

---

## Resetting Everything

If you want a completely fresh start:

1. Run `scripts\uninstall.bat` (say Yes to remove volume and models)
2. Run `install.bat` again
