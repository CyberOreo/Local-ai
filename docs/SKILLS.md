# Local AI Skills

14 skills that make your AI smarter — document reading, web search, YouTube transcripts, meeting analysis, and more.

---

## Setup (One Time)

### Step 1 — Install Python packages

Run this after `start.bat` has Local AI running:

```
config\skills\install-skill-packages.bat
```

> Re-run this after `update.bat` — package installs are wiped when the container updates. (update.bat does this automatically)

### Step 2 — Install Tools in Open WebUI

For each tool `.py` file in `config/skills/tools/`:

1. Open **http://localhost:3000**
2. Click your avatar (top right) → **Admin Panel**
3. Click **Tools** in the left sidebar
4. Click **+ Add Tool**
5. Delete the existing code and paste the tool's `.py` file contents
6. Click **Save**

### Step 3 — Enable Tools in Chat

In the chat window, click the **+** icon next to the message box and toggle each tool on.

### Step 4 — Set Up System Prompts (Optional)

For behavior-shaping prompts (debugging, brainstorming, kaizen):

1. Go to **Admin Panel** → **Models**
2. Create a new model based on `qwen3.5:9b-maxperf`
3. Paste the contents of the `.txt` file into the **System Prompt** field
4. Save and use that model when you need that behavior

---

## Available Tools

### Tier 1 — No extra packages needed

| Tool file | What it does | Trigger phrase |
|-----------|-------------|----------------|
| `youtube-transcript-tool.py` | Fetch transcripts from YouTube videos | "summarize this YouTube video: URL" |
| `article-extractor-tool.py` | Extract full text from any web page | "read this article: URL" |
| `web-search-tool.py` | Search DuckDuckGo (no API key) | "search for X" |
| `sanitize-tool.py` | Detect and remove PII from text | "sanitize this text" |
| `meeting-insights-tool.py` | Analyze meeting transcripts | "analyze this meeting transcript" |

### Tier 2 — Requires `install-skill-packages.bat`

| Tool file | Package needed | What it does | Trigger phrase |
|-----------|---------------|-------------|----------------|
| `pdf-reader-tool.py` | pypdf | Read PDF files | "read this PDF: C:/path/to/file.pdf" |
| `docx-reader-tool.py` | python-docx | Read Word documents | "read this Word file: C:/path/file.docx" |
| `xlsx-reader-tool.py` | openpyxl | Read Excel spreadsheets | "analyze this spreadsheet: C:/path/file.xlsx" |
| `csv-summarizer-tool.py` | (stdlib) | Analyze CSV data | "analyze this CSV: C:/path/file.csv" |
| `deep-research-tool.py` | beautifulsoup4 | Multi-step web research | "research everything about X" |
| `tapestry-tool.py` | (stdlib) | Link documents in a folder | "scan my documents in C:/path/folder" |

---

## System Prompts

| File | What it does | When to use |
|------|-------------|-------------|
| `systematic-debugging.txt` | Forces step-by-step root-cause analysis before fixes | Debugging sessions |
| `brainstorming.txt` | Structured diverge → cluster → stress-test ideation | Creative sessions |
| `kaizen.txt` | Continuous improvement lens on any process or system | Code/process reviews |

---

## Example Usage

**YouTube:**
> "Summarize this YouTube video: https://youtube.com/watch?v=..."

**PDF:**
> "Read this PDF and give me the key points: C:/Users/You/Documents/report.pdf"

**Web search:**
> "Search for the latest news about open source AI models"

**Meeting:**
> "Here's the meeting transcript from today: [paste transcript]. Analyze it and give me action items."

**Deep research:**
> "Research everything about running LLMs locally on consumer hardware"

**PII:**
> "Sanitize this customer data before I send it to support: [paste data]"

---

## Troubleshooting

**"Not installed" error in chat**
→ Run `config\skills\install-skill-packages.bat` and try again.

**After update.bat, tools stop working**
→ Run `install-skill-packages.bat` again. (Or use update.bat — it does this automatically now.)

**YouTube: "Video has no captions"**
→ The video may have auto-generated captions disabled. Try a different video.

**PDF: "No text extracted"**
→ The PDF is image-based (scanned document). OCR is not supported yet.

**Article extractor returns little text**
→ The page requires JavaScript or a login. Ask me to search for it instead.
