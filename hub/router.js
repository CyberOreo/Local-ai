/**
 * NeuralBox — Model Router
 * Selects provider + model based on task type and execution profile.
 * Called by efficiency.js and hub.js for every generation request.
 */

'use strict';

// ── Profile definitions ──────────────────────────────────────────────────────

const PROFILES = {
  'Local Only': {
    stage1: 'local_primary',
    stage2: 'local_primary',
    stage3: null,
    description: 'Always uses your local Ollama model. Free, private, no internet required.',
  },
  'Cheapest Possible': {
    stage1: 'local_backup',
    stage2: 'local_backup',
    stage3: null,
    description: 'Uses your fastest/smallest local model for maximum speed.',
  },
  'Best Value': {
    stage1: 'local_primary',
    stage2: 'api_cheap',
    stage3: null,
    description: 'Local draft, optional cheap API polish if key is configured.',
  },
  'Balanced': {
    stage1: 'local_primary',
    stage2: 'api_cheap',
    stage3: 'api_standard',
    description: 'Local draft → cheap polish → optional premium finish.',
  },
  'Highest Quality': {
    stage1: 'api_standard',
    stage2: 'api_standard',
    stage3: 'api_premium',
    description: 'Uses external API for all stages. Requires API key.',
  },
  'Premium Final Polish': {
    stage1: 'local_primary',
    stage2: 'api_standard',
    stage3: 'api_premium',
    description: 'Local draft, premium API polish. Best quality/cost ratio.',
  },
};

// ── Task-based default profiles ──────────────────────────────────────────────

const TASK_DEFAULTS = {
  tiktok_hook:      'Local Only',
  caption:          'Local Only',
  caption_pack:     'Local Only',
  bio:              'Local Only',
  quick_template:   'Local Only',
  template:         'Local Only',
  youtube_starter:  'Best Value',
  brand_builder:    'Best Value',
  offer:            'Best Value',
  landing_page:     'Balanced',
  agency_toolkit:   'Balanced',
  outreach:         'Balanced',
  money_mode:       'Balanced',
  worker:           'Balanced',
  worker_idea:      'Local Only',
  worker_script:    'Best Value',
  worker_repurpose: 'Local Only',
  worker_offer:     'Best Value',
  worker_planner:   'Best Value',
  final_polish:     'Premium Final Polish',
};

// ── Provider/model resolution ────────────────────────────────────────────────

const PROVIDER_INFO = {
  local_primary:  { provider: 'ollama', cost_label: 'Free',     cost_usd: 0 },
  local_backup:   { provider: 'ollama', cost_label: 'Free',     cost_usd: 0 },
  api_cheap:      { provider: 'groq',   cost_label: 'Budget',   cost_usd: 0.0004 },
  api_standard:   { provider: 'openai', cost_label: 'Balanced', cost_usd: 0.005 },
  api_premium:    { provider: 'anthropic', cost_label: 'Premium', cost_usd: 0.015 },
};

// Determine which external providers are actually available (have keys)
function getAvailableProviders(settings) {
  const keys = settings.api_keys || {};
  return {
    groq:      !!(keys.groq      && keys.groq.trim()),
    openai:    !!(keys.openai    && keys.openai.trim()),
    anthropic: !!(keys.anthropic && keys.anthropic.trim()),
  };
}

// Resolve a tier string to actual provider + model
function resolveTier(tier, settings, available) {
  const primary = settings.primary_model || 'qwen3.5:9b';
  const backup  = settings.backup_model  || 'qwen3.5:4b';

  if (tier === 'local_primary') {
    return { provider: 'ollama', model: primary, cost_label: 'Free', cost_usd: 0 };
  }
  if (tier === 'local_backup') {
    return { provider: 'ollama', model: backup, cost_label: 'Free', cost_usd: 0 };
  }

  // External — fall back through hierarchy if key not available
  if (tier === 'api_cheap') {
    if (available.groq)   return { provider: 'groq',  model: 'llama-3.1-8b-instant', cost_label: 'Budget',  cost_usd: 0.0004 };
    if (available.openai) return { provider: 'openai', model: 'gpt-4o-mini',          cost_label: 'Budget',  cost_usd: 0.0008 };
    // fallback to local
    return { provider: 'ollama', model: primary, cost_label: 'Free', cost_usd: 0, fallback: true };
  }
  if (tier === 'api_standard') {
    if (available.openai)    return { provider: 'openai',    model: 'gpt-4o-mini',      cost_label: 'Balanced', cost_usd: 0.005 };
    if (available.groq)      return { provider: 'groq',      model: 'llama-3.3-70b-versatile', cost_label: 'Balanced', cost_usd: 0.002 };
    if (available.anthropic) return { provider: 'anthropic', model: 'claude-haiku-4-5-20251001', cost_label: 'Balanced', cost_usd: 0.003 };
    return { provider: 'ollama', model: primary, cost_label: 'Free', cost_usd: 0, fallback: true };
  }
  if (tier === 'api_premium') {
    if (available.anthropic) return { provider: 'anthropic', model: 'claude-sonnet-4-6', cost_label: 'Premium', cost_usd: 0.015 };
    if (available.openai)    return { provider: 'openai',    model: 'gpt-4o',            cost_label: 'Premium', cost_usd: 0.02 };
    return { provider: 'ollama', model: primary, cost_label: 'Free', cost_usd: 0, fallback: true };
  }

  return { provider: 'ollama', model: primary, cost_label: 'Free', cost_usd: 0 };
}

// ── Main routing function ────────────────────────────────────────────────────

/**
 * routeModel(taskType, profileName, settings, stage)
 *
 * Returns:
 * {
 *   provider: 'ollama'|'openai'|'anthropic'|'groq',
 *   model: string,
 *   cost_label: 'Free'|'Budget'|'Balanced'|'Premium',
 *   cost_usd: number,
 *   reason: string,
 *   cheaper_alt: string|null,
 *   fallback: boolean,
 *   profile: string,
 *   stage: string
 * }
 */
function routeModel(taskType, profileName, settings, stage = 'stage1') {
  const available = getAvailableProviders(settings);

  // Determine profile
  const resolvedProfile = profileName && PROFILES[profileName]
    ? profileName
    : (TASK_DEFAULTS[taskType] || 'Balanced');

  const profile = PROFILES[resolvedProfile];
  const tierKey = profile[stage] || profile.stage1;

  if (!tierKey) {
    // Stage 3 premium not configured in this profile — skip
    return null;
  }

  const resolved = resolveTier(tierKey, settings, available);

  // Build reason string
  let reason = '';
  if (resolved.provider === 'ollama') {
    if (resolved.fallback) {
      reason = `No API key configured for ${tierKey.replace('api_', '')} — using local ${resolved.model}`;
    } else {
      reason = `Local model selected. ${profile.description}`;
    }
  } else {
    reason = `${resolvedProfile} profile: ${profile.description}`;
  }

  // Cheaper alternative suggestion
  let cheaper_alt = null;
  if (resolved.cost_usd > 0) {
    const localResult = resolveTier('local_primary', settings, available);
    cheaper_alt = `Use "Local Only" for free (${localResult.model})`;
  }

  return {
    ...resolved,
    reason,
    cheaper_alt,
    fallback: resolved.fallback || false,
    profile:  resolvedProfile,
    stage,
  };
}

// ── Smart per-task recommendation ─────────────────────────────────────────────

function recommendProfile(taskType) {
  const profile = TASK_DEFAULTS[taskType] || 'Balanced';
  const info    = PROFILES[profile];
  return {
    recommended_profile: profile,
    description: info.description,
  };
}

// ── Budget check ─────────────────────────────────────────────────────────────

/**
 * Returns whether a call is allowed given current spend and settings.
 */
function checkBudget(costUsd, spendInfo, settings) {
  const daily_limit  = settings.daily_limit_usd         || 1.00;
  const per_worker   = settings.per_worker_budget_usd   || 0.10;
  const premium_max  = settings.premium_calls_per_day   || 5;

  if (costUsd === 0) return { allowed: true };

  if (spendInfo.today_usd >= daily_limit) {
    return { allowed: false, reason: 'Daily limit reached — switching to local model' };
  }

  if ((spendInfo.today_usd / daily_limit) >= 0.80) {
    return { allowed: true, warning: `Approaching daily limit ($${spendInfo.today_usd.toFixed(4)} / $${daily_limit})` };
  }

  return { allowed: true };
}

// ── Profile list for UI ───────────────────────────────────────────────────────

function listProfiles() {
  return Object.entries(PROFILES).map(([name, p]) => ({
    name,
    description: p.description,
    has_stage3: !!p.stage3,
  }));
}

module.exports = { routeModel, recommendProfile, checkBudget, listProfiles, PROFILES, TASK_DEFAULTS };
