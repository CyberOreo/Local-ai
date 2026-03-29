"""
title: Local AI Updater
description: Update Ollama, Open WebUI and AI models directly from chat. Type 'update' or 'check update status'.
author: LocalAI
version: 1.1
license: MIT
"""

# ============================================================
# HOW TO INSTALL THIS TOOL IN OPEN WEBUI:
#
# 1. Open http://localhost:3000
# 2. Click your avatar (top right) → Admin Panel
# 3. Click "Tools" in the left sidebar
# 4. Click "+ Add Tool" (top right)
# 5. Delete all existing code in the editor
# 6. Paste THIS entire file into the editor
# 7. Click "Save"
# 8. Go back to chat
# 9. Click the "+" icon next to the message box → enable "Local AI Updater"
#
# USAGE:
#   Type: "update"                  → starts the update
#   Type: "check update status"     → shows progress
#   Type: "is everything up to date?" → same as status
# ============================================================

import urllib.request
import urllib.error
import json
import time

UPDATE_SERVER = "http://host.docker.internal:9999"


class Tools:

    def __init__(self):
        pass

    def update_local_ai(self) -> str:
        """
        Updates everything: Ollama runtime, Open WebUI chat interface, and AI models.
        Safe: models are never deleted. Only changed parts are downloaded (delta update).
        Your chat history is always preserved.
        Trigger phrases: update, update everything, run update, check for updates
        """
        # First check server is reachable
        health = self._get(f"{UPDATE_SERVER}/api/health")
        if health is None:
            return (
                "❌ **Update server not reachable.**\n\n"
                "Make sure Local AI is running (start.bat).\n"
                "Then try again.\n\n"
                "Alternative: double-click **update.bat** in the project folder."
            )

        # Trigger the update
        result = self._get(f"{UPDATE_SERVER}/api/update")
        if result is None:
            return "❌ Failed to start update. Check that start.bat is running."

        status = result.get("status", "")

        if status == "already_running":
            return (
                "⏳ **Update is already in progress.**\n\n"
                "Ask me *'check update status'* to see the latest progress."
            )

        if status == "started":
            return (
                "✅ **Update started!**\n\n"
                "Running in the background — your chat is not interrupted.\n\n"
                "**What's updating:**\n"
                "- Ollama runtime\n"
                "- Open WebUI interface\n"
                "- qwen3.5:9b model *(smart delta — 0 bytes if unchanged)*\n"
                "- qwen3.5:4b backup model *(smart delta)*\n\n"
                "**Your chat history is preserved.**\n\n"
                "Ask me *'check update status'* in a few minutes to see progress.\n"
                "You may need to refresh the page after the update completes."
            )

        return f"⚠️ Unexpected response: {result}"

    def check_update_status(self) -> str:
        """
        Shows the current progress of a running update, or confirms everything is up to date.
        Trigger phrases: check update status, update status, is it done, update progress
        """
        result = self._get(f"{UPDATE_SERVER}/api/status")
        if result is None:
            return (
                "❌ **Cannot reach update server.**\n\n"
                "Make sure Local AI is running (start.bat)."
            )

        status    = result.get("status", "unknown")
        message   = result.get("message", "")
        timestamp = result.get("timestamp", "")
        steps     = result.get("steps", [])
        errors    = result.get("errors", [])

        # Build steps list (last 8 entries to keep it readable)
        steps_text = ""
        if steps:
            recent = steps[-8:]
            steps_text = "\n\n**Progress log:**\n" + "\n".join(f"  {s}" for s in recent)

        errors_text = ""
        if errors:
            errors_text = "\n\n**Warnings:**\n" + "\n".join(f"  ⚠️ {e}" for e in errors)

        if status == "idle":
            return f"✅ **System is idle.** No update is running.\n\nType *'update'* to start one."

        if status == "running":
            return (
                f"🔄 **Update in progress...**\n\n"
                f"Current step: {message}"
                f"{steps_text}"
                f"{errors_text}\n\n"
                f"*Ask me again in a minute for the latest progress.*"
            )

        if status == "complete":
            return (
                f"✅ **Update complete!**\n\n"
                f"{message}"
                f"{steps_text}"
                f"{errors_text}\n\n"
                f"*You may need to refresh this page (F5) to get the latest interface.*"
            )

        if status == "error":
            return (
                f"❌ **Update encountered an error.**\n\n"
                f"{message}"
                f"{steps_text}"
                f"{errors_text}\n\n"
                f"*Try running **update.bat** from the project folder for more details.*"
            )

        return f"Status: **{status}**\n{message}{steps_text}"

    # ── Internal helper ──────────────────────────────────────

    def _get(self, url: str, timeout: int = 10):
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.URLError:
            return None
        except Exception:
            return None
