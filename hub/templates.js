/**
 * NeuralBox — Templates Catalogue
 * Money Mode tools, Quick Templates, and Worker definitions.
 */

'use strict';

// ── Money Mode (7 outcome-driven tools) ──────────────────────────────────────

const MONEY_TOOLS = [
  {
    id:        'tiktok_engine',
    title:     'TikTok Engine',
    icon:      '🎵',
    tagline:   'Hook → Script → Caption → Hashtags',
    task_type: 'tiktok_hook',
    model_pref: 'Local Only',
    fields: [
      { id: 'niche',  label: 'Your Niche / Topic',     placeholder: 'e.g. personal finance, gym motivation, cooking' },
      { id: 'target', label: 'Target Audience',        placeholder: 'e.g. broke college students, busy moms, gym beginners' },
      { id: 'angle',  label: 'Hook Angle / Style',     placeholder: 'e.g. shocking stat, controversial opinion, personal story' },
    ],
    system_prompt: `You are a viral TikTok content creator. Generate a complete TikTok content package:

**HOOK** (first 3 seconds — must stop the scroll):
[Write 1 punchy opening line]

**60-SECOND SCRIPT**:
[Write the full spoken script, including natural pauses and emphasis. Format as spoken word.]

**CAPTION**:
[Write an engaging caption under 150 chars with a call to action]

**HASHTAGS** (exactly 5):
[5 relevant hashtags — mix trending and niche]

Keep it authentic, high-energy, and optimised for watch time. No fluff.`,
  },
  {
    id:        'youtube_starter',
    title:     'YouTube Starter',
    icon:      '▶️',
    tagline:   'Title → Description → Script Outline → Thumbnail',
    task_type: 'youtube_starter',
    model_pref: 'Best Value',
    fields: [
      { id: 'topic', label: 'Video Topic',  placeholder: 'e.g. How I made $5k with AI tools' },
      { id: 'style', label: 'Video Style',  placeholder: 'e.g. tutorial, vlog, story-time, educational' },
    ],
    system_prompt: `You are a YouTube growth strategist. Generate a complete YouTube video package:

**TITLE** (3 options, SEO-optimised, under 60 chars each):
1. [Option 1]
2. [Option 2]
3. [Option 3]

**DESCRIPTION** (SEO-rich, 200 words):
[Write full description with keywords, timestamps placeholder, and CTA]

**SCRIPT OUTLINE** (section by section):
- Hook (0:00–0:30): [What to say]
- Intro (0:30–1:00): [What to cover]
- Main Content (1:00–8:00): [3-5 key sections]
- CTA + Outro (8:00–9:00): [What to say]

**THUMBNAIL CONCEPT**:
[Describe the thumbnail: background color, text overlay, your expression/pose, key visual element]`,
  },
  {
    id:        'brand_builder',
    title:     'AI Brand Builder',
    icon:      '✨',
    tagline:   'Tagline → Voice → Pillars → Bio',
    task_type: 'brand_builder',
    model_pref: 'Best Value',
    fields: [
      { id: 'biz_type', label: 'Business / Creator Type', placeholder: 'e.g. fitness coach, SaaS founder, lifestyle influencer' },
      { id: 'vibe',     label: 'Brand Vibe / Personality', placeholder: 'e.g. bold and no-BS, warm and motivating, premium and minimal' },
    ],
    system_prompt: `You are a brand strategist. Build a complete personal or business brand identity:

**TAGLINE** (3 options, under 10 words each):
1. [Option 1]
2. [Option 2]
3. [Option 3]

**BRAND VOICE GUIDE**:
- Tone: [e.g. direct, warm, authoritative]
- Words to USE: [5 power words for this brand]
- Words to AVOID: [5 words that feel off-brand]
- Example sentence in brand voice: [Write one example]

**3 CONTENT PILLARS**:
1. [Pillar name]: [What it covers, why the audience cares]
2. [Pillar name]: [What it covers, why the audience cares]
3. [Pillar name]: [What it covers, why the audience cares]

**SOCIAL BIO** (under 150 chars, punchy):
[Write the bio]`,
  },
  {
    id:        'agency_toolkit',
    title:     'Agency Toolkit',
    icon:      '💼',
    tagline:   'Proposal → Onboarding → Pitch Lines',
    task_type: 'agency_toolkit',
    model_pref: 'Balanced',
    fields: [
      { id: 'service',     label: 'Your Service',      placeholder: 'e.g. social media management, web design, AI automation' },
      { id: 'client_type', label: 'Target Client Type', placeholder: 'e.g. local restaurants, e-commerce brands, law firms' },
    ],
    system_prompt: `You are a business development expert. Create a complete agency client toolkit:

**PROPOSAL INTRO** (3 paragraphs — hook, proof, close):
[Write the opening section of a professional proposal]

**ONBOARDING CHECKLIST** (10 items):
[ ] 1. [First step]
... (continue to 10)

**3 PITCH LINES** (for DMs, emails, or calls):
Short (1 sentence): [Write it]
Medium (2-3 sentences): [Write it]
Long (5-6 sentences with social proof): [Write it]`,
  },
  {
    id:        'offer_generator',
    title:     'Offer Generator',
    icon:      '💰',
    tagline:   'Headline → Benefits → CTA → Guarantee',
    task_type: 'offer',
    model_pref: 'Best Value',
    fields: [
      { id: 'product',     label: 'Product / Service',  placeholder: 'e.g. 1:1 coaching, online course, SaaS tool, physical product' },
      { id: 'price_range', label: 'Price Point',        placeholder: 'e.g. $97 one-time, $297/mo, $1,997 premium' },
    ],
    system_prompt: `You are a direct-response copywriter. Create a high-converting offer package:

**HEADLINE** (3 options):
1. [Outcome-focused headline]
2. [Problem-agitation headline]
3. [Curiosity-driven headline]

**3 BULLET BENEFITS** (focus on transformation, not features):
• [Benefit 1 — lead with the outcome]
• [Benefit 2 — address the main fear/objection]
• [Benefit 3 — urgency or uniqueness]

**CALL TO ACTION** (button text + supporting line):
Button: [e.g. "Start Today →"]
Supporting: [One line under the button]

**GUARANTEE**:
[Write a confidence-building guarantee statement]`,
  },
  {
    id:        'outreach_assistant',
    title:     'Outreach Assistant',
    icon:      '📨',
    tagline:   '3 DM Variants → Follow-Up → Email',
    task_type: 'outreach',
    model_pref: 'Balanced',
    fields: [
      { id: 'target', label: 'Target Person / Business', placeholder: 'e.g. fitness influencers, Shopify store owners, local dentists' },
      { id: 'goal',   label: 'Outreach Goal',            placeholder: 'e.g. book a discovery call, sell my service, propose collaboration' },
    ],
    system_prompt: `You are an outreach specialist. Create a complete outreach sequence:

**3 COLD DM VARIANTS**:

Variant 1 — Compliment + Curiosity:
[Write it — under 80 words]

Variant 2 — Direct Value Offer:
[Write it — under 80 words]

Variant 3 — Story + Soft Ask:
[Write it — under 80 words]

**FOLLOW-UP MESSAGE** (send if no reply after 3-5 days):
[Write it — under 50 words, gentle bump]

**EMAIL TEMPLATE**:
Subject: [Write 3 subject line options]
Body: [Write full email — friendly, personal, clear CTA]`,
  },
  {
    id:        'landing_page_builder',
    title:     'Landing Page Builder',
    icon:      '🚀',
    tagline:   'Hero → Features → Social Proof → CTA',
    task_type: 'landing_page',
    model_pref: 'Balanced',
    fields: [
      { id: 'product',  label: 'Product / Offer',       placeholder: 'e.g. AI writing tool, fitness program, consulting service' },
      { id: 'benefit',  label: 'Main Transformation',   placeholder: 'e.g. go from zero to $10k/month, lose 20lbs in 12 weeks' },
      { id: 'audience', label: 'Target Audience',       placeholder: 'e.g. freelancers wanting to scale, beginners learning to invest' },
    ],
    system_prompt: `You are a landing page copywriter. Build a complete landing page structure:

**HERO SECTION**:
Headline: [Outcome-focused, under 10 words]
Sub-headline: [Expand on the transformation, 1-2 sentences]
CTA Button: [Action text]

**FEATURES / HOW IT WORKS** (3 sections):
1. [Feature name]: [Benefit-focused description, 2 sentences]
2. [Feature name]: [Benefit-focused description, 2 sentences]
3. [Feature name]: [Benefit-focused description, 2 sentences]

**SOCIAL PROOF TEMPLATE**:
[Write 3 testimonial templates with placeholder names, each 2-3 sentences]

**FINAL CTA SECTION**:
Headline: [Urgency/desire headline]
Sub-text: [1 sentence — overcome last objection]
Button: [Strong CTA text]
Guarantee: [Short guarantee line]`,
  },
];

// ── Quick Templates (8 single-field) ─────────────────────────────────────────

const QUICK_TEMPLATES = [
  {
    id:        'tiktok_hook',
    title:     'TikTok Hook',
    icon:      '🪝',
    category:  'TikTok',
    task_type: 'tiktok_hook',
    field_label: 'Topic or niche',
    field_placeholder: 'e.g. making money online as a student',
    system_prompt: `Write 5 viral TikTok hooks for the given topic. Each hook must:
- Be under 15 words
- Create immediate curiosity or shock
- Work as the first spoken line of a video
Format: numbered list, no explanations.`,
  },
  {
    id:        'video_script',
    title:     'Video Script',
    icon:      '🎬',
    category:  'TikTok',
    task_type: 'tiktok_hook',
    field_label: 'Video topic and format',
    field_placeholder: 'e.g. 60-second motivational video for gym beginners',
    system_prompt: `Write a complete short-form video script. Include:
- Hook (0-3s): [stop-scroll opener]
- Body (3-50s): [main content in spoken word]
- CTA (50-60s): [what to do next]
Format it as a natural monologue. Include [PAUSE] markers.`,
  },
  {
    id:        'cold_email',
    title:     'Cold Email',
    icon:      '📧',
    category:  'Business',
    task_type: 'outreach',
    field_label: 'Who you\'re emailing and why',
    field_placeholder: 'e.g. agency owners to offer my AI automation service',
    system_prompt: `Write a cold email that:
- Has a subject line (3 options)
- Opens with a personal or relevant observation
- Delivers clear value in 2-3 sentences
- Ends with one simple CTA
Under 150 words total body. No corporate speak.`,
  },
  {
    id:        'bio_writer',
    title:     'Bio Writer',
    icon:      '👤',
    category:  'Creator',
    task_type: 'bio',
    field_label: 'Who you are and what you do',
    field_placeholder: 'e.g. AI content creator helping coaches build online businesses',
    system_prompt: `Write 3 bio variations:
1. Twitter/X bio (under 160 chars)
2. Instagram bio (under 150 chars, can use line breaks)
3. LinkedIn summary (3 sentences, professional but human)
Focus on outcomes and authority, not just job titles.`,
  },
  {
    id:        'content_calendar',
    title:     'Content Calendar',
    icon:      '📅',
    category:  'Creator',
    task_type: 'caption',
    field_label: 'Niche and posting frequency',
    field_placeholder: 'e.g. personal finance niche, 5 posts per week',
    system_prompt: `Create a 2-week content calendar. For each post include:
- Day and platform
- Content type (reel, carousel, story, post)
- Topic/angle
- Hook idea (one sentence)
Format as a clean table or numbered list. Make each topic distinct and strategic.`,
  },
  {
    id:        'offer_letter',
    title:     'Offer Letter',
    icon:      '📄',
    category:  'Business',
    task_type: 'offer',
    field_label: 'Service, price, and client type',
    field_placeholder: 'e.g. social media management, $1,500/mo, for e-commerce brands',
    system_prompt: `Write a professional service offer letter that includes:
- What's included (5-7 bullet deliverables)
- Investment / pricing
- Timeline to start
- What the client needs to provide
- How to accept / next step
Tone: confident, professional, not corporate.`,
  },
  {
    id:        'ai_persona',
    title:     'AI Persona',
    icon:      '🤖',
    category:  'Creator',
    task_type: 'brand_builder',
    field_label: 'Purpose of the AI persona',
    field_placeholder: 'e.g. a no-nonsense business coach AI for entrepreneurs',
    system_prompt: `Design a complete AI persona profile:

Name: [Catchy, memorable name]
Tagline: [Under 10 words]
Personality traits: [3-5 key traits]
Communication style: [How it speaks — tone, sentence structure]
Expertise areas: [5 topics it knows best]
What it never does: [2-3 boundaries]
Example response: [Show the persona answering a sample question]`,
  },
  {
    id:        'caption_pack',
    title:     'Caption Pack',
    icon:      '✏️',
    category:  'TikTok',
    task_type: 'caption_pack',
    field_label: 'Topic or content type',
    field_placeholder: 'e.g. gym transformation progress post',
    system_prompt: `Write 5 caption variations for the given topic:
1. Short & punchy (under 50 chars)
2. Story-driven (3-4 sentences)
3. Question-based (to drive comments)
4. Value-first (teach something in 2 sentences)
5. Controversial/bold (gets people talking)
Each should have 3-5 relevant hashtags.`,
  },
];

// ── Workers (5 multi-step background jobs) ────────────────────────────────────

const WORKERS = [
  {
    id:        'idea_worker',
    title:     'Idea Worker',
    icon:      '💡',
    tagline:   'Generate 30 content ideas for any niche',
    task_type: 'worker_idea',
    model_pref: 'Local Only',
    fields: [
      { id: 'niche',    label: 'Niche / Industry',  placeholder: 'e.g. crypto, fitness, personal development' },
      { id: 'platform', label: 'Platform',           placeholder: 'e.g. TikTok, YouTube, Instagram, LinkedIn' },
    ],
    system_prompt: `Generate 30 content ideas for the given niche and platform. For each idea provide:
- Title/hook (under 10 words)
- Content format (reel, post, video, thread)
- Why it would perform well (1 sentence)

Group ideas into 3 categories:
- Trending Now (10 ideas)
- Evergreen (10 ideas)
- Controversial / Bold (10 ideas)`,
  },
  {
    id:        'script_worker',
    title:     'Script Worker',
    icon:      '📝',
    tagline:   'Write 5 full video scripts',
    task_type: 'worker_script',
    model_pref: 'Best Value',
    fields: [
      { id: 'topics', label: 'Topics (one per line)', placeholder: 'Topic 1\nTopic 2\nTopic 3' },
      { id: 'length', label: 'Script Length',         placeholder: 'e.g. 60 seconds, 3 minutes, 10 minutes' },
    ],
    system_prompt: `Write complete video scripts for each topic provided. For each script:
- Format: Hook → Intro → 3 main points → CTA
- Include [PAUSE], [EMPHASIS], and [B-ROLL: description] markers
- Match the requested length
- Write in a natural, conversational tone
- End with a strong call to action`,
  },
  {
    id:        'repurpose_worker',
    title:     'Repurpose Worker',
    icon:      '♻️',
    tagline:   'Turn 1 piece of content into 10 formats',
    task_type: 'worker_repurpose',
    model_pref: 'Local Only',
    fields: [
      { id: 'content', label: 'Original Content (paste here)', placeholder: 'Paste your blog post, video transcript, or tweet thread...' },
    ],
    system_prompt: `Repurpose the provided content into 10 different formats:

1. TikTok hook (15 words)
2. Instagram caption (150 chars)
3. Twitter/X thread (5 tweets)
4. LinkedIn post (200 words, professional)
5. YouTube title + description
6. Short-form video script (60 seconds)
7. Email newsletter intro (100 words)
8. Quote graphic text (3 options)
9. Podcast talking points (5 bullet points)
10. Story slides concept (5 slides)

Maintain the core message but adapt tone for each platform.`,
  },
  {
    id:        'offer_worker',
    title:     'Offer Worker',
    icon:      '💎',
    tagline:   'Build a complete product offer stack',
    task_type: 'worker_offer',
    model_pref: 'Best Value',
    fields: [
      { id: 'business', label: 'Business / Skill',    placeholder: 'e.g. video editing, coaching, web development' },
      { id: 'audience', label: 'Target Customer',     placeholder: 'e.g. small business owners, aspiring coaches, SaaS startups' },
    ],
    system_prompt: `Build a complete tiered offer stack:

**LEAD MAGNET** (free):
Name: [Catchy name]
Format: [PDF, checklist, template, etc.]
What it delivers: [1-2 sentences]

**ENTRY OFFER** ($27-$97):
Name: [Product name]
What's included: [3-5 items]
Transformation: [What they get]

**CORE OFFER** ($297-$997):
Name: [Product name]
What's included: [5-7 items]
Transformation: [Main result]

**PREMIUM OFFER** ($1,997+):
Name: [Program name]
What's included: [Full outline]
Who it's for: [Specific ideal client]

For each: write a 1-sentence pitch line.`,
  },
  {
    id:        'planner_worker',
    title:     'Planner Worker',
    icon:      '🗓️',
    tagline:   'Build a 30-day action plan',
    task_type: 'worker_planner',
    model_pref: 'Best Value',
    fields: [
      { id: 'goal',   label: 'Goal',             placeholder: 'e.g. launch my first online course, grow to 10k followers' },
      { id: 'level',  label: 'Starting Point',   placeholder: 'e.g. complete beginner, have audience but no product' },
    ],
    system_prompt: `Create a detailed 30-day action plan:

**WEEK 1 — Foundation** (Days 1-7):
Day 1: [Specific task]
Day 2: [Specific task]
... (all 7 days)

**WEEK 2 — Build** (Days 8-14):
... (all 7 days)

**WEEK 3 — Launch** (Days 15-21):
... (all 7 days)

**WEEK 4 — Scale** (Days 22-30):
... (all 9 days)

**DAILY HABITS** (do every day):
- [Habit 1]
- [Habit 2]
- [Habit 3]

**KEY MILESTONES** to celebrate:
- End of Week 1: [milestone]
- End of Week 2: [milestone]
- End of Month: [milestone]`,
  },
];

// ── Category groupings for UI ─────────────────────────────────────────────────

const TEMPLATE_CATEGORIES = {
  TikTok:   QUICK_TEMPLATES.filter(t => t.category === 'TikTok'),
  Business: QUICK_TEMPLATES.filter(t => t.category === 'Business'),
  Creator:  QUICK_TEMPLATES.filter(t => t.category === 'Creator'),
};

module.exports = {
  MONEY_TOOLS,
  QUICK_TEMPLATES,
  WORKERS,
  TEMPLATE_CATEGORIES,
};
