"""
title: Article Extractor
description: Extract and read the full text of any web article or page. Trigger with: "read this article: URL"
author: LocalAI
version: 1.0
license: MIT
"""

import urllib.request
import urllib.error
import re


class Tools:

    def extract_article(self, url: str) -> str:
        """
        Extracts the full readable text from a web page or article URL.
        Trigger phrases: read this article, extract text from, summarize this page, what does this say, open this link
        :param url: The URL of the article or web page
        :return: The extracted article text
        """
        try:
            from bs4 import BeautifulSoup
        except ImportError:
            return (
                "❌ **beautifulsoup4 not installed.**\n\n"
                "Run `install-skill-packages.bat` in the Local AI folder to install it.\n"
                "Then try again."
            )

        headers = {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            )
        }

        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=15) as resp:
                html = resp.read().decode("utf-8", errors="replace")
        except urllib.error.URLError as e:
            return f"❌ Could not fetch URL: {e}\n\nCheck the URL and your internet connection."
        except Exception as e:
            return f"❌ Error fetching page: {e}"

        soup = BeautifulSoup(html, "html.parser")

        # Remove noise elements
        for tag in soup(["script", "style", "nav", "header", "footer",
                         "aside", "form", "button", "iframe", "noscript"]):
            tag.decompose()

        # Try article tag first, then main, then body
        content = soup.find("article") or soup.find("main") or soup.find("body")
        if content:
            text = content.get_text(separator="\n", strip=True)
        else:
            text = soup.get_text(separator="\n", strip=True)

        # Clean up excessive blank lines
        text = re.sub(r"\n{3,}", "\n\n", text).strip()
        word_count = len(text.split())

        if word_count < 50:
            return f"⚠️ Very little text extracted from {url}. The page may require JavaScript or a login."

        title_tag = soup.find("title")
        title = title_tag.get_text(strip=True) if title_tag else url

        return (
            f"✅ **Article extracted** ({word_count} words)\n\n"
            f"**Title:** {title}\n"
            f"**Source:** {url}\n\n"
            f"---\n\n{text}"
        )
