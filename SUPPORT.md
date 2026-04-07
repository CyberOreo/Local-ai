# NeuralBox Support

## Quick Troubleshooting

### Hub won't start
1. Ensure Node.js 18+ is installed: `node --version`
2. Run `_engine/fix-launch.bat` to diagnose and restart services
3. Check `logs/` directory for error output

### Ollama not showing as online
1. Open a terminal and run: `ollama serve`
2. Verify the model is downloaded: `ollama list`
3. If no models listed, pull one: `ollama pull qwen3.5:9b`

### Open WebUI (Chat) offline
1. Ensure Docker Desktop is running
2. Run `_engine/fix-webui.bat`
3. Check Docker logs: `docker logs open-webui`

### API key not working
1. Go to Settings → API Keys → click "Test Connection"
2. Verify the key has not expired in the provider dashboard
3. Check spend limits — a depleted account returns auth errors

### Workers not completing
1. Check System Status for OpenClaw health
2. If OpenClaw is offline, workers fall back to direct Ollama — ensure Ollama is running
3. Restart services via `_engine/launcher/restart-ai.bat`

## Useful Files

| File | Purpose |
|------|---------|
| `~/.neuralbox/history.json` | All generated outputs |
| `~/.neuralbox/settings.json` | Your local settings overrides |
| `~/.neuralbox/spend.json` | Daily spend log |
| `logs/` | Startup and error logs |

## Getting Help

- Open an issue on the project GitHub repository
- Include the System Status diagnostics (Settings → System Status → Copy Diagnostics)
