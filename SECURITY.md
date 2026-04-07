# NeuralBox Security Policy

## Overview

NeuralBox binds exclusively to `127.0.0.1` (localhost). It is not accessible from other
machines on your network by default.

## Sensitive Data Handling

- **API keys** are stored only in `~/.neuralbox/settings.json` (your user home directory)
- API keys are never stored inside the project directory (which may be synced to git)
- The UI masks API keys — only the last 4 characters are visible after saving
- NeuralBox never logs or transmits API keys

## Reporting a Vulnerability

If you discover a security vulnerability in NeuralBox, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email the maintainer directly (see repository contact) with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact

We aim to acknowledge reports within 72 hours and release a fix within 14 days for
critical issues.

## Scope

The following are in scope for security reports:

- Authentication/authorization bypass
- Remote code execution via the hub server
- Data exfiltration paths
- Prompt injection leading to system access

## Out of Scope

- Vulnerabilities in Ollama, Docker, Open WebUI, or OpenClaw (report to those projects)
- Social engineering
- Physical access attacks
