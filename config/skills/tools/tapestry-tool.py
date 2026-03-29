"""
title: Tapestry - Document Linker
description: Scan a folder of documents, find connections between them, and build a knowledge map.
author: LocalAI
version: 1.0
license: MIT
"""

import os
import re
from collections import defaultdict


class Tools:

    def scan_documents(self, folder_path: str, extensions: str = ".txt,.md,.py,.ps1,.bat") -> str:
        """
        Scans a folder for text documents, extracts key terms, and identifies connections between files.
        Trigger phrases: scan my documents, link these files, build knowledge map, connect my notes, tapestry
        :param folder_path: Path to the folder to scan
        :param extensions: Comma-separated list of file extensions to include
        :return: Document map with connections and summaries
        """
        if not os.path.isdir(folder_path):
            return f"❌ Folder not found: `{folder_path}`"

        ext_list = [e.strip().lower() for e in extensions.split(",")]
        files_found = []

        for root, dirs, files in os.walk(folder_path):
            # Skip hidden/system dirs
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("node_modules", "__pycache__")]
            for fname in files:
                if any(fname.lower().endswith(ext) for ext in ext_list):
                    files_found.append(os.path.join(root, fname))

        if not files_found:
            return (
                f"⚠️ No matching files found in `{folder_path}`\n\n"
                f"Searched for: {extensions}\n"
                f"Try a different folder or extension list."
            )

        output = [
            f"🕸️ **Tapestry Document Map**\n"
            f"Folder: `{folder_path}`\n"
            f"Files found: {len(files_found)}\n"
        ]

        # Read each file and extract key terms
        doc_data = {}
        for fpath in files_found[:50]:  # cap at 50 files
            try:
                with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read(8000)  # first 8KB
                words = re.findall(r'\b[A-Za-z][a-z]{3,}\b', content)
                # Get top 30 frequent words (excluding stop words)
                stop = {"this", "that", "with", "from", "have", "will", "been",
                        "they", "their", "what", "when", "where", "which", "there",
                        "then", "also", "some", "into", "more", "about", "would",
                        "could", "should", "each", "than", "your", "just", "only"}
                freq = defaultdict(int)
                for w in words:
                    wl = w.lower()
                    if wl not in stop and len(wl) > 3:
                        freq[wl] += 1
                top_terms = sorted(freq.items(), key=lambda x: -x[1])[:30]
                doc_data[fpath] = {
                    "terms": set(t for t, _ in top_terms),
                    "preview": content[:200].replace("\n", " ").strip(),
                    "size": len(content)
                }
            except Exception:
                pass

        # Find connections (shared key terms)
        file_list = list(doc_data.keys())
        connections = defaultdict(list)
        for i in range(len(file_list)):
            for j in range(i + 1, len(file_list)):
                a, b = file_list[i], file_list[j]
                shared = doc_data[a]["terms"] & doc_data[b]["terms"]
                if len(shared) >= 3:
                    connections[a].append((b, sorted(shared)[:8]))
                    connections[b].append((a, sorted(shared)[:8]))

        # Output document summaries
        output.append("## Documents\n")
        for fpath, data in doc_data.items():
            rel = os.path.relpath(fpath, folder_path)
            linked_count = len(connections.get(fpath, []))
            output.append(f"**{rel}** ({data['size']} chars, {linked_count} connections)")
            output.append(f"> {data['preview']}...\n")

        # Output connections
        if connections:
            output.append("## Connections\n")
            shown = set()
            for fpath, links in connections.items():
                for linked_path, shared_terms in links:
                    pair = tuple(sorted([fpath, linked_path]))
                    if pair in shown:
                        continue
                    shown.add(pair)
                    a_rel = os.path.relpath(fpath, folder_path)
                    b_rel = os.path.relpath(linked_path, folder_path)
                    output.append(f"🔗 **{a_rel}** ↔ **{b_rel}**")
                    output.append(f"   Shared topics: {', '.join(shared_terms)}\n")
        else:
            output.append("*No strong connections found between documents.*")

        return "\n".join(output)
