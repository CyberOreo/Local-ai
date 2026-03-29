"""
title: YouTube Transcript Fetcher
description: Fetch and summarize transcripts from YouTube videos. Trigger with: "summarize this YouTube video: URL"
author: LocalAI
version: 1.0
license: MIT
"""

import urllib.request
import urllib.error
import json
import re


class Tools:

    def fetch_youtube_transcript(self, url: str) -> str:
        """
        Fetches the transcript of a YouTube video and returns it for summarization.
        Trigger phrases: summarize youtube, transcript of, watch this video, youtube.com, youtu.be
        :param url: The YouTube video URL
        :return: The full transcript text ready for summarization
        """
        video_id = self._extract_video_id(url)
        if not video_id:
            return f"❌ Could not extract video ID from URL: {url}\nPlease provide a valid YouTube URL."

        try:
            from youtube_transcript_api import YouTubeTranscriptApi
            transcript_list = YouTubeTranscriptApi.get_transcript(video_id)
            full_text = " ".join(entry["text"] for entry in transcript_list)
            word_count = len(full_text.split())
            return (
                f"✅ **Transcript fetched** ({word_count} words)\n\n"
                f"**Video ID:** {video_id}\n\n"
                f"**Transcript:**\n\n{full_text}"
            )
        except ImportError:
            return (
                "❌ **youtube-transcript-api not installed.**\n\n"
                "Run `install-skill-packages.bat` in the Local AI folder to install it.\n"
                "Then try again."
            )
        except Exception as e:
            return f"❌ Could not fetch transcript: {e}\n\nThe video may have no captions, or captions may be disabled."

    def _extract_video_id(self, url: str) -> str:
        patterns = [
            r"(?:v=|youtu\.be/)([A-Za-z0-9_-]{11})",
            r"(?:embed/)([A-Za-z0-9_-]{11})",
            r"(?:shorts/)([A-Za-z0-9_-]{11})",
        ]
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return ""
