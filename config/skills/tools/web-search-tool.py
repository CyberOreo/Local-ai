"""
title: Web Search (DuckDuckGo)
description: Search the web using DuckDuckGo. No API key needed. Trigger with: "search for X" or "look up X"
author: LocalAI
version: 1.0
license: MIT
"""

import urllib.request
import urllib.parse
import json
import re


class Tools:

    def search_web(self, query: str, num_results: int = 8) -> str:
        """
        Searches DuckDuckGo for the given query and returns the top results.
        Trigger phrases: search for, look up, find information about, google, search the web
        :param query: The search query
        :param num_results: Number of results to return (default 8, max 15)
        :return: List of search results with titles, URLs, and snippets
        """
        num_results = min(max(1, num_results), 15)

        # DuckDuckGo Instant Answer API (no key needed)
        encoded = urllib.parse.quote_plus(query)
        api_url = f"https://api.duckduckgo.com/?q={encoded}&format=json&no_redirect=1&no_html=1&skip_disambig=1"

        headers = {
            "User-Agent": "Mozilla/5.0 (compatible; LocalAI/1.0)"
        }

        try:
            req = urllib.request.Request(api_url, headers=headers)
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except Exception as e:
            return f"❌ Search failed: {e}"

        results = []

        # Abstract (top result)
        if data.get("AbstractText") and data.get("AbstractURL"):
            results.append({
                "title": data.get("Heading", "Top Result"),
                "url": data["AbstractURL"],
                "snippet": data["AbstractText"]
            })

        # Related topics
        for topic in data.get("RelatedTopics", []):
            if len(results) >= num_results:
                break
            if isinstance(topic, dict) and topic.get("Text") and topic.get("FirstURL"):
                results.append({
                    "title": self._clean_title(topic["FirstURL"]),
                    "url": topic["FirstURL"],
                    "snippet": topic["Text"]
                })
            elif isinstance(topic, dict) and topic.get("Topics"):
                for sub in topic["Topics"]:
                    if len(results) >= num_results:
                        break
                    if sub.get("Text") and sub.get("FirstURL"):
                        results.append({
                            "title": self._clean_title(sub["FirstURL"]),
                            "url": sub["FirstURL"],
                            "snippet": sub["Text"]
                        })

        if not results:
            return (
                f"🔍 No instant results found for: **{query}**\n\n"
                f"Try rephrasing, or ask me to extract a specific article with its URL."
            )

        output = [f"🔍 **Search results for:** {query}\n"]
        for i, r in enumerate(results, 1):
            output.append(f"**{i}. {r['title']}**")
            output.append(f"   {r['snippet']}")
            output.append(f"   🔗 {r['url']}\n")

        return "\n".join(output)

    def _clean_title(self, url: str) -> str:
        path = urllib.parse.urlparse(url).path
        parts = [p for p in path.split("/") if p]
        if parts:
            return parts[-1].replace("_", " ").replace("-", " ").title()
        return url
