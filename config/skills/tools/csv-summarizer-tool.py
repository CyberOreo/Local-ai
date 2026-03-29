"""
title: CSV Data Analyzer
description: Analyze CSV data files and provide insights. Trigger with: "analyze this CSV: /path/to/file.csv"
author: LocalAI
version: 1.0
license: MIT
"""

import csv
import os
from statistics import mean, median, stdev


class Tools:

    def analyze_csv(self, file_path: str, max_preview_rows: int = 20) -> str:
        """
        Reads a CSV file and provides column stats, data preview, and insights.
        Trigger phrases: analyze this CSV, read CSV file, summarize CSV data, CSV analysis
        :param file_path: Path to the CSV file
        :param max_preview_rows: Number of rows to show in preview (default 20)
        :return: CSV analysis with stats and preview
        """
        if not os.path.isfile(file_path):
            return f"❌ File not found: `{file_path}`"

        ext = os.path.splitext(file_path)[1].lower()
        if ext not in (".csv", ".tsv", ".txt"):
            return f"❌ Expected a CSV file. Got: `{ext}`"

        try:
            # Detect delimiter
            with open(file_path, "r", encoding="utf-8-sig", errors="replace") as f:
                sample = f.read(4096)
            dialect = csv.Sniffer().sniff(sample) if sample else None
            delimiter = dialect.delimiter if dialect else ","

            with open(file_path, "r", encoding="utf-8-sig", errors="replace") as f:
                reader = csv.DictReader(f, dialect=dialect or "excel")
                headers = reader.fieldnames or []
                rows = list(reader)

            total_rows = len(rows)
            total_cols = len(headers)

            if total_rows == 0:
                return f"⚠️ CSV file `{os.path.basename(file_path)}` has no data rows."

            output = [
                f"✅ **CSV Analysis:** `{os.path.basename(file_path)}`\n"
                f"Rows: {total_rows} | Columns: {total_cols} | Delimiter: `{repr(delimiter)}`\n"
            ]

            # Column analysis
            output.append("## Column Summary\n")
            for col in headers:
                values = [r[col] for r in rows if r.get(col, "").strip()]
                empty_count = total_rows - len(values)
                numeric_values = []
                for v in values:
                    try:
                        numeric_values.append(float(v.replace(",", "")))
                    except (ValueError, AttributeError):
                        pass

                col_info = f"**{col}** — {len(values)} non-empty"
                if empty_count > 0:
                    col_info += f", {empty_count} empty"

                if numeric_values and len(numeric_values) / max(len(values), 1) > 0.7:
                    mn = min(numeric_values)
                    mx = max(numeric_values)
                    avg = round(mean(numeric_values), 3)
                    med = round(median(numeric_values), 3)
                    col_info += f" | numeric: min={mn}, max={mx}, avg={avg}, median={med}"
                    if len(numeric_values) > 1:
                        try:
                            sd = round(stdev(numeric_values), 3)
                            col_info += f", stdev={sd}"
                        except Exception:
                            pass
                else:
                    unique_vals = set(v.strip() for v in values if v.strip())
                    if len(unique_vals) <= 10:
                        col_info += f" | values: {', '.join(sorted(unique_vals))}"
                    else:
                        col_info += f" | {len(unique_vals)} unique values"

                output.append(f"- {col_info}")

            # Data preview
            preview_rows = rows[:max_preview_rows]
            output.append(f"\n## Data Preview (first {len(preview_rows)} rows)\n")

            # Header row
            output.append(" | ".join(headers))
            output.append(" | ".join(["---"] * len(headers)))

            for row in preview_rows:
                cells = [str(row.get(h, "")).replace("\n", " ")[:50] for h in headers]
                output.append(" | ".join(cells))

            if total_rows > max_preview_rows:
                output.append(f"\n*...{total_rows - max_preview_rows} more rows not shown*")

            return "\n".join(output)

        except Exception as e:
            return f"❌ Error reading CSV: {e}"
