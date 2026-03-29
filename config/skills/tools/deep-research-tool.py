"""
title: Deep Research
description: Multi-step web research on any topic. Searches, reads top results, and synthesizes findings.
author: LocalAI
version: 1.0
license: MIT
"""

import urllib.request
import urllib.parse
import json
import re


class Tools:

    def deep_research(self, topic: str, depth: int = 3) -> str:
        """
        Performs multi-step research: searches the web, fetches top articles,
        and returns synthesized content for the AI to analyze.
        Trigger phrases: research, deep dive, investigate, find everything about, comprehensive overview
        :param topic: The topic to research
        :param depth: Number of articles to fetch and read (1-5, default 3)
        :return: Research findings from multiple sources
        """
        depth = min(max(1, depth), 5)

        output = [f"🔬 **Deep Research: {topic}**\n"]
        output.append(f"Searching {depth} sources...\n")

        # Step 1: Search DuckDuckGo
        search_results = self._search_ddg(topic, num_results=depth + 2)
        if not search_results:
            return (
                f"❌ Could not retrieve search results for: **{topic}**\n\n"
                "Check your internet connection and try again."
            )

        output.append(f"Found {len(search_results)} sources. Fetching content...\n")

        # Step 2: Fetch content from top results
        fetched = 0
        for i, result in enumerate(search_results):
            if fetched >= depth:
                break
            url = result.get("url", "")
            if not url or not url.startswith("http"):
                continue

            text = self._fetch_page_text(url)
            if not text or len(text.split()) < 100:
                continue

            fetched += 1
            word_count = len(text.split())
            # Trim to ~600 words per source to stay within context
            words = text.split()
            if len(words) > 600:
                text = " ".join(words[:600]) + "..."

            output.append(f"---\n### Source {fetched}: {result.get('title', url)}")
            output.append(f"🔗 {url} | {word_count} words extracted\n")
            output.append(text)
            output.append("")

        if fetched == 0:
            return (
                f"⚠️ Found search results for **{topic}** but could not fetch article content.\n\n"
                "Sources may require JavaScript. Try asking me to search instead."
            )

        output.append("---")
        output.append(
            f"\n📊 **Research complete.** {fetched} sources analyzed.\n\n"
            f"Please synthesize the above sources into a comprehensive answer about: **{topic}**\n"
            f"Include key findings, different perspectives, and note any conflicting information."
        )

        return "\n".join(output)

    def _search_ddg(self, query: str, num_results: int = 5):
        encoded = urllib.parse.quote_plus(query)
        url = f"https://api.duckduckgo.com/?q={encoded}&format=json&no_redirect=1&no_html=1&skip_disambig=1"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "LocalAI/1.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except Exception:
            return []

        results = []
        if data.get("AbstractText") and data.get("AbstractURL"):
            results.append({"title": data.get("Heading", query), "url": data["AbstractURL"]})

        for topic in data.get("RelatedTopics", []):
            if len(results) >= num_results:
                break
            if isinstance(topic, dict) and topic.get("FirstURL"):
                results.append({"title": topic.get("Text", "")[:80], "url": topic["FirstURL"]})
            elif isinstance(topic, dict) and topic.get("Topics"):
                for sub in topic["Topics"]:
                    if len(results) >= num_results:
                        break
                    if sub.get("FirstURL"):
                        results.append({"title": sub.get("Text", "")[:80], "url": sub["FirstURL"]})

        return results

    def _fetch_page_text(self, url: str) -> str:
        headers = {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            )
        }
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=10) as resp:
                html = resp.read().decode("utf-8", errors="replace")
        except Exception:
            return ""

        try:
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(html, "html.parser")
            for tag in soup(["script", "style", "nav", "header", "footer", "aside"]):
                tag.decompose()
            content = soup.find("article") or soup.find("main") or soup.find("body")
            text = content.get_text(separator=" ", strip=True) if content else ""
            return re.sub(r"\s{2,}", " ", text).strip()
        except ImportError:
            # Fallback: crude HTML tag stripping
            text = re.sub(r"<[^>]+>", " ", html)
            return re.sub(r"\s{2,}", " ", text).strip()
        except Exception:
            return ""
