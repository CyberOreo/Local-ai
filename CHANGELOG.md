# NeuralBox Changelog

## [1.0.0] — 2025-04-02

### Added — Commercial Product Launch

**Core Architecture**
- Full 8-section SPA replacing single-page dashboard
- Hash-based client-side routing with animated section transitions
- Fixed sidebar navigation with budget spend indicator

**Backend Modules**
- `hub/router.js` — Hybrid model routing engine with 6 execution profiles
- `hub/storage.js` — File-based history, settings, and spend tracking at `~/.neuralbox/`
- `hub/templates.js` — Full template catalogue (Money Mode, Quick Templates, Workers)
- `hub/efficiency.js` — Stage-based generation with budget protection system

**New API Endpoints**
- `GET /api/onboarding` — Hardware check + model list + first-run flag
- `POST /api/generate` — AI generation with routing, cost tracking, auto-save
- `GET/POST /api/history` — Load and save output history
- `DELETE /api/history/:id` — Delete individual history items
- `GET/POST /api/settings` — Load and update user settings
- `POST /api/keys/test` — Validate external API keys
- `POST /api/worker/start` — Start background worker jobs
- `GET /api/worker/status` — Poll worker queue status

**Money Mode (7 Tools)**
- TikTok Engine — Hook + 60s script + caption + hashtags
- YouTube Starter — Title + description + script outline + thumbnail idea
- AI Brand Builder — Tagline + brand voice + content pillars + bio
- Agency Toolkit — Proposal + onboarding checklist + pitch lines
- Offer Generator — Headline + benefits + CTA + guarantee
- Outreach Assistant — Cold DM variants + follow-up + email template
- Landing Page Builder — Hero + features + social proof + CTA

**Quick Templates (8)**
TikTok Hook, Video Script, Cold Email, Bio Writer, Content Calendar,
Offer Letter, AI Persona, Caption Pack

**Workers (5)**
Idea Worker, Script Worker, Repurpose Worker, Offer Worker, Planner Worker

**Hybrid AI Routing**
- 6 routing profiles: Local Only, Cheapest Possible, Best Value, Balanced, Highest Quality, Premium Final Polish
- Task-based smart defaults per feature type
- Per-result explanation: model chosen, reason, cost label, cheaper alternative
- Stage-based generation: Draft → Polish → Premium finish

**Budget & Cost Controls**
- Daily spend limit (default $1.00)
- Per-worker budget cap (default $0.10)
- Premium calls per day limit (default 5)
- Ask-before-expensive toggle
- Visual spend bar in sidebar with warning at 80%, lock at 100%
- Cost labels: Free / Budget / Balanced / Premium

**First-Run Onboarding**
- 3-step modal: Welcome + privacy statement → Hardware check → Ready screen
- Privacy messaging: "Local by default. Nothing leaves your machine unless you enable external AI providers."
- Auto-dismissed permanently after completion

**Commercial Files**
- MIT License
- Privacy Policy (`PRIVACY.md`)
- Terms of Use (`TERMS.md`)
- Security Policy (`SECURITY.md`)
- Support Guide (`SUPPORT.md`)
- Third-Party Notices (`THIRD_PARTY_NOTICES.md`)

**Branding**
- Unified "NeuralBox" branding across all files
- Hub title/color updated in `hub-start.bat`

### Changed
- `config/settings.json` — Added budget controls, routing rules, profile names
- `hub/hub.js` — Full rewrite with all new API routes, real stats (no fake counters)
- `hub/index.html` — Full rewrite as 8-section SPA

### Fixed
- Removed fake auto-incrementing request counter
- Real request count tracked server-side
- `project_name` corrected to "NeuralBox"

---

## [0.9.x] — Pre-release

Initial single-page dashboard with 5 API endpoints.
