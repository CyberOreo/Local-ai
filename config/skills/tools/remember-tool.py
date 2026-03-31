"""
title: Remember
description: Lets Clawbot remember facts about you, your projects, and preferences. Makes the AI smarter over time by building a personal knowledge base.
author: LocalAI
version: 1.0.0
"""

import json
import os
import datetime
from typing import Optional


class Tools:
    def __init__(self):
        self.memory_file = os.path.join(os.path.expanduser("~"), ".clawbot_memory.json")

    def _load(self) -> dict:
        if os.path.exists(self.memory_file):
            try:
                with open(self.memory_file, "r") as f:
                    return json.load(f)
            except Exception:
                pass
        return {"facts": [], "preferences": {}, "projects": {}}

    def _save(self, data: dict):
        try:
            with open(self.memory_file, "w") as f:
                json.dump(data, f, indent=2)
        except Exception:
            pass

    def remember(self, fact: str, category: str = "general") -> str:
        """
        Store a fact or piece of information for future reference.
        Use this whenever the user mentions something important about themselves,
        their work, preferences, or ongoing projects.
        :param fact: The fact to remember (e.g. "User's name is Alex", "User prefers Python over JavaScript", "Working on a mobile app for fitness tracking")
        :param category: Category tag: 'about_me', 'preference', 'project', 'work', 'technical', or 'general'
        :return: Confirmation that the fact was saved
        """
        data = self._load()
        entry = {
            "fact": fact,
            "category": category,
            "saved_at": datetime.datetime.now().isoformat(),
        }
        data["facts"].append(entry)
        self._save(data)
        return f"Remembered: {fact} (category: {category})"

    def recall(self, topic: str = "") -> str:
        """
        Retrieve stored memories. Use at the start of conversations to recall
        context about the user and their projects.
        :param topic: Optional topic to filter by (e.g. "project", "preference") — leave blank to get all memories
        :return: All relevant memories
        """
        data = self._load()
        facts = data.get("facts", [])

        if not facts:
            return "No memories stored yet. I'll start learning about you as we talk!"

        if topic:
            filtered = [f for f in facts if topic.lower() in f.get("category", "").lower()
                       or topic.lower() in f.get("fact", "").lower()]
        else:
            filtered = facts

        if not filtered:
            return f"No memories found for topic '{topic}'."

        lines = [f"**Memories{' about ' + topic if topic else ''}:**\n"]
        # Group by category
        categories = {}
        for f in filtered:
            cat = f.get("category", "general")
            if cat not in categories:
                categories[cat] = []
            categories[cat].append(f["fact"])

        for cat, items in categories.items():
            lines.append(f"**{cat.replace('_', ' ').title()}:**")
            for item in items:
                lines.append(f"  - {item}")
            lines.append("")

        return "\n".join(lines)

    def forget(self, fact_fragment: str) -> str:
        """
        Remove a specific memory. Use when information is outdated or incorrect.
        :param fact_fragment: Part of the fact to remove (will match any fact containing this text)
        :return: Confirmation of what was removed
        """
        data = self._load()
        original_count = len(data["facts"])
        data["facts"] = [f for f in data["facts"]
                        if fact_fragment.lower() not in f.get("fact", "").lower()]
        removed = original_count - len(data["facts"])
        self._save(data)

        if removed == 0:
            return f"No memory found containing '{fact_fragment}'."
        return f"Removed {removed} memory/memories containing '{fact_fragment}'."

    def memory_summary(self) -> str:
        """
        Get a compact summary of everything remembered about the user.
        Use this at the start of a new conversation for context.
        :return: Summary of all stored memories
        """
        data = self._load()
        facts = data.get("facts", [])

        if not facts:
            return "Memory is empty. Tell me about yourself and I'll remember it!"

        count = len(facts)
        categories = {}
        for f in facts:
            cat = f.get("category", "general")
            categories[cat] = categories.get(cat, 0) + 1

        lines = [f"**Memory Summary** ({count} total facts)\n"]
        for cat, cnt in sorted(categories.items(), key=lambda x: -x[1]):
            lines.append(f"  - {cat.replace('_', ' ').title()}: {cnt} fact(s)")

        lines.append("\nType 'recall' to see all memories, or 'recall [topic]' to filter.")
        return "\n".join(lines)
