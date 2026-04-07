# NeuralBox Privacy Policy

**Last updated: April 2025**

## Summary

NeuralBox is designed to run entirely on your local machine.

> **Local by default. Nothing leaves your machine unless you enable external AI providers.**

---

## What NeuralBox Does

- Runs AI models locally via Ollama
- Stores your outputs, history, and settings in `~/.neuralbox/` on your own computer
- Optionally connects to external AI APIs (OpenAI, Anthropic, Groq) only if you explicitly configure API keys

## What NeuralBox Does NOT Do

- Does not collect telemetry, analytics, or usage data
- Does not phone home to any server
- Does not store your data in any cloud service
- Does not share your prompts, outputs, or settings with anyone
- Does not require an account or registration

## Data Storage

All data is stored locally on your machine:

| Data | Location |
|------|----------|
| Generated outputs & history | `~/.neuralbox/history.json` |
| Settings & preferences | `~/.neuralbox/settings.json` |
| Spend tracking | `~/.neuralbox/spend.json` |
| Memory facts | `~/.clawbot_memory.json` |

## External AI Providers (Optional)

If you add API keys in Settings → API Keys:

- Your prompts are sent to those providers (OpenAI, Anthropic, Groq) per their own privacy policies
- You are subject to their respective terms of service and data practices
- You can remove API keys at any time to return to fully local operation

NeuralBox shows a clear cost label ("Free", "Budget", "Balanced", "Premium") on every
generated output so you always know which provider was used.

## Contact

For privacy concerns, open an issue at the project repository.
