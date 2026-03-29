"""
title: PDF Reader
description: Extract and read text from PDF files. Trigger with: "read this PDF: /path/to/file.pdf"
author: LocalAI
version: 1.0
license: MIT
"""

import os


class Tools:

    def read_pdf(self, file_path: str, max_pages: int = 20) -> str:
        """
        Extracts text from a PDF file and returns it for analysis or summarization.
        Trigger phrases: read this PDF, summarize this PDF, extract text from PDF, open PDF
        :param file_path: Path to the PDF file (e.g. C:/Users/You/Documents/report.pdf)
        :param max_pages: Maximum number of pages to extract (default 20)
        :return: Extracted text from the PDF
        """
        try:
            import pypdf
        except ImportError:
            return (
                "❌ **pypdf not installed.**\n\n"
                "Run `install-skill-packages.bat` in the Local AI folder to install it.\n"
                "Then try again."
            )

        if not os.path.isfile(file_path):
            return (
                f"❌ File not found: `{file_path}`\n\n"
                "Make sure the path is correct. Use forward slashes or double backslashes.\n"
                "Example: `C:/Users/You/Documents/report.pdf`"
            )

        if not file_path.lower().endswith(".pdf"):
            return f"❌ This tool only reads PDF files. Got: `{os.path.basename(file_path)}`"

        try:
            reader = pypdf.PdfReader(file_path)
            total_pages = len(reader.pages)
            pages_to_read = min(total_pages, max_pages)

            text_parts = []
            for i in range(pages_to_read):
                page_text = reader.pages[i].extract_text() or ""
                if page_text.strip():
                    text_parts.append(f"--- Page {i+1} ---\n{page_text.strip()}")

            if not text_parts:
                return (
                    f"⚠️ No text could be extracted from `{os.path.basename(file_path)}`.\n\n"
                    "The PDF may be image-based (scanned). OCR is not supported in this version."
                )

            full_text = "\n\n".join(text_parts)
            word_count = len(full_text.split())

            header = (
                f"✅ **PDF extracted:** `{os.path.basename(file_path)}`\n"
                f"Pages read: {pages_to_read}/{total_pages} | Words: {word_count}\n\n"
            )
            if total_pages > max_pages:
                header += f"⚠️ Only first {max_pages} pages shown. Pass `max_pages` to read more.\n\n"

            return header + full_text

        except Exception as e:
            return f"❌ Error reading PDF: {e}"
