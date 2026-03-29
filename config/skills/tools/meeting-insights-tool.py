"""
title: Meeting Insights Analyzer
description: Analyze meeting transcripts to extract key decisions, action items, and insights.
author: LocalAI
version: 1.0
license: MIT
"""

import re


class Tools:

    def analyze_meeting_transcript(self, transcript: str) -> str:
        """
        Analyzes a meeting transcript and extracts: action items, decisions made,
        key topics discussed, open questions, and a brief summary.
        Trigger phrases: analyze this meeting, meeting transcript, meeting notes, action items from
        :param transcript: The meeting transcript text
        :return: Structured meeting analysis with action items, decisions, and summary
        """
        if not transcript or len(transcript.strip()) < 50:
            return "❌ Please provide a meeting transcript with at least a few lines of content."

        word_count = len(transcript.split())
        line_count = len([l for l in transcript.splitlines() if l.strip()])

        # Detect action item phrases
        action_patterns = [
            r'(?:action item|todo|to do|will|going to|should|needs? to|must|assigned to|follow.?up)[:\s]+([^\n.!?]{10,120})',
            r'(?:AI|A\.I\.)[:\s]+([^\n.!?]{10,120})',
            r'(?:\[\s*action\s*\])[:\s]*([^\n.!?]{10,120})',
        ]
        action_items = []
        for pattern in action_patterns:
            matches = re.findall(pattern, transcript, re.IGNORECASE)
            action_items.extend([m.strip() for m in matches if len(m.strip()) > 15])
        action_items = list(dict.fromkeys(action_items))[:15]  # deduplicate, max 15

        # Detect decisions
        decision_patterns = [
            r'(?:decided|agreed|confirmed|approved|resolved|conclusion|we will|team will)[:\s]+([^\n.!?]{10,120})',
            r'(?:decision)[:\s]+([^\n.!?]{10,120})',
        ]
        decisions = []
        for pattern in decision_patterns:
            matches = re.findall(pattern, transcript, re.IGNORECASE)
            decisions.extend([m.strip() for m in matches if len(m.strip()) > 15])
        decisions = list(dict.fromkeys(decisions))[:10]

        # Detect open questions
        question_patterns = [
            r'([^\n.!?]{10,100}\?)',
            r'(?:open question|unresolved|TBD|to be determined)[:\s]+([^\n.!?]{10,100})',
        ]
        questions = []
        for pattern in question_patterns:
            matches = re.findall(pattern, transcript, re.IGNORECASE)
            questions.extend([m.strip() for m in matches if len(m.strip()) > 10])
        questions = list(dict.fromkeys(questions))[:8]

        # Detect participants (Name: or Name said)
        participant_patterns = [
            r'^([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)\s*[:>]',
            r'\b([A-Z][a-z]+)\s+said\b',
        ]
        participants = set()
        for pattern in participant_patterns:
            matches = re.findall(pattern, transcript, re.MULTILINE)
            participants.update(matches)
        participants = sorted(participants)[:20]

        # Build output
        output = ["📋 **Meeting Analysis**\n"]
        output.append(f"*Transcript: {word_count} words, {line_count} lines*\n")

        if participants:
            output.append(f"**Participants detected:** {', '.join(participants)}\n")

        if action_items:
            output.append("## ✅ Action Items")
            for i, item in enumerate(action_items, 1):
                output.append(f"{i}. {item}")
            output.append("")
        else:
            output.append("## ✅ Action Items\n*None explicitly detected — review transcript manually.*\n")

        if decisions:
            output.append("## 🔷 Decisions Made")
            for i, d in enumerate(decisions, 1):
                output.append(f"{i}. {d}")
            output.append("")

        if questions:
            output.append("## ❓ Open Questions")
            for i, q in enumerate(questions[:5], 1):
                output.append(f"{i}. {q}")
            output.append("")

        output.append("## 📝 Summary Request")
        output.append(
            "Based on the transcript and extracted items above, "
            "please provide a concise summary of what was discussed and decided."
        )

        return "\n".join(output)
