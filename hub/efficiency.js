/**
 * NeuralBox — Efficiency for Money System
 * Stage-based AI generation with budget protection.
 * Orchestrates calls through OpenClaw (if available) or direct Ollama/API.
 */

'use strict';

const { routeModel, checkBudget, checkPremiumCallsExceeded } = require('./router.js');
const { trackSpend, getSpend }    = require('./storage.js');

// ── HTTP helpers ──────────────────────────────────────────────────────────────

async function httpPost(url, body, timeoutMs = 30000) {
  const ctrl  = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(body),
      signal:  ctrl.signal,
    });
    clearTimeout(timer);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    clearTimeout(timer);
    throw err;
  }
}

async function serviceAlive(url, timeoutMs = 1500) {
  try {
    const ctrl  = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    const res   = await fetch(url, { signal: ctrl.signal });
    clearTimeout(timer);
    return res.status < 500;
  } catch {
    return false;
  }
}

// ── Provider call implementations ─────────────────────────────────────────────

async function callOllama(model, systemPrompt, userPrompt, ollamaPort = 11434) {
  const url  = `http://localhost:${ollamaPort}/api/generate`;
  const body = {
    model,
    prompt:  userPrompt,
    system:  systemPrompt,
    stream:  false,
    options: { temperature: 0.8, num_predict: 2048 },
  };
  const data = await httpPost(url, body, 60000);
  return {
    text:   (data.response || '').trim(),
    tokens: (data.prompt_eval_count || 0) + (data.eval_count || 0),
  };
}

async function callOpenAI(model, systemPrompt, userPrompt, apiKey) {
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method:  'POST',
    headers: {
      'Content-Type':  'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system',  content: systemPrompt },
        { role: 'user',    content: userPrompt   },
      ],
      max_tokens:  2048,
      temperature: 0.8,
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error?.message || `OpenAI HTTP ${res.status}`);
  }
  const data = await res.json();
  return {
    text:   (data.choices?.[0]?.message?.content || '').trim(),
    tokens: data.usage?.total_tokens || 0,
  };
}

async function callAnthropic(model, systemPrompt, userPrompt, apiKey) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method:  'POST',
    headers: {
      'Content-Type':      'application/json',
      'x-api-key':         apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model,
      max_tokens: 2048,
      system:     systemPrompt,
      messages:   [{ role: 'user', content: userPrompt }],
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error?.message || `Anthropic HTTP ${res.status}`);
  }
  const data = await res.json();
  return {
    text:   (data.content?.[0]?.text || '').trim(),
    tokens: (data.usage?.input_tokens || 0) + (data.usage?.output_tokens || 0),
  };
}

async function callGroq(model, systemPrompt, userPrompt, apiKey) {
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method:  'POST',
    headers: {
      'Content-Type':  'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user',   content: userPrompt   },
      ],
      max_tokens:  2048,
      temperature: 0.8,
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error?.message || `Groq HTTP ${res.status}`);
  }
  const data = await res.json();
  return {
    text:   (data.choices?.[0]?.message?.content || '').trim(),
    tokens: data.usage?.total_tokens || 0,
  };
}

// ── OpenClaw gateway call ─────────────────────────────────────────────────────

async function callOpenClaw(model, systemPrompt, userPrompt) {
  const body = {
    model:    `ollama/${model}`,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user',   content: userPrompt   },
    ],
  };
  const data = await httpPost('http://localhost:18789/v1/chat/completions', body, 120000);
  const text = data.choices?.[0]?.message?.content || data.response || '';
  return {
    text:   text.trim(),
    tokens: data.usage?.total_tokens || 0,
  };
}

// ── Dispatch to correct provider ──────────────────────────────────────────────

async function callProvider(routing, systemPrompt, userPrompt, settings) {
  const { provider, model } = routing;
  const keys = settings.api_keys || {};

  if (provider === 'ollama') {
    return callOllama(model, systemPrompt, userPrompt, settings.ollama_port || 11434);
  }
  if (provider === 'openai') {
    return callOpenAI(model, systemPrompt, userPrompt, keys.openai);
  }
  if (provider === 'anthropic') {
    return callAnthropic(model, systemPrompt, userPrompt, keys.anthropic);
  }
  if (provider === 'groq') {
    return callGroq(model, systemPrompt, userPrompt, keys.groq);
  }
  throw new Error(`Unknown provider: ${provider}`);
}

// ── Stage combiner — builds polish prompt ────────────────────────────────────

function buildPolishPrompt(draft, originalPrompt, stage) {
  if (stage === 'stage2') {
    return `Here is a draft output:\n\n${draft}\n\nPlease improve it: tighten the language, fix any awkward phrasing, and make it more compelling. Keep the same structure and format. Return the improved version only.`;
  }
  if (stage === 'stage3') {
    return `Here is content that needs a professional final polish:\n\n${draft}\n\nElevate this to publication quality. Make it exceptional. Return only the final polished version.`;
  }
  return originalPrompt;
}

// ── Main generate function ────────────────────────────────────────────────────

/**
 * generate(options) → { result, model_used, provider, cost_label, cost_usd, tokens, reason, cheaper_alt, stages_run, spend }
 *
 * options: { systemPrompt, userPrompt, taskType, profileName, settings, maxStage, budgetCap, jobId }
 *   budgetCap: optional per-job USD limit (overrides per_worker_budget_usd if lower)
 *   jobId: optional string for per-job spend tracking
 * maxStage: 1 | 2 | 3 (default from profile; user can override)
 */
async function generate(options) {
  const {
    systemPrompt,
    userPrompt,
    taskType    = 'template',
    profileName = null,
    settings    = {},
    maxStage    = 2,
    budgetCap   = null,  // hard per-job limit in USD
    jobId       = null,
  } = options;

  const spendInfo  = getSpend(settings);

  // Hard-block if daily limit already reached
  if (spendInfo.locked) {
    throw new Error(`Daily budget limit reached ($${settings.daily_limit_usd || 1.00}). API calls blocked. Using local only mode.`);
  }

  // Resolve effective per-job cap
  const perWorkerCap = settings.per_worker_budget_usd || 0.10;
  const effectiveCap = budgetCap != null
    ? Math.min(budgetCap, perWorkerCap)
    : perWorkerCap;

  const stagesRun  = [];
  let   currentText  = '';
  let   totalTokens  = 0;
  let   totalCost    = 0;  // cost accumulated in this job
  let   finalRouting = null;
  let   openclawAvailable = null;

  for (let stageNum = 1; stageNum <= maxStage; stageNum++) {
    const stageKey = `stage${stageNum}`;
    const routing  = routeModel(taskType, profileName, settings, stageKey);

    if (!routing) continue; // profile doesn't have this stage

    // Budget check for non-free stages
    if (routing.cost_usd > 0) {
      // 1. Check daily limit
      const budget = checkBudget(routing.cost_usd, spendInfo, settings);
      // 2. Check per-job cap
      const jobBudgetExceeded = (totalCost + routing.cost_usd) > effectiveCap;
      // 3. Check premium calls per day
      const premiumBlocked = checkPremiumCallsExceeded(routing.cost_label, settings);

      if (!budget.allowed || jobBudgetExceeded || premiumBlocked) {
        const reason = !budget.allowed
          ? budget.reason
          : jobBudgetExceeded
            ? `Per-job budget cap ($${effectiveCap.toFixed(4)}) would be exceeded — using local model`
            : `Daily premium call limit (${settings.premium_calls_per_day || 5}) reached — using local model`;

        // Fallback to local for this stage
        const localRouting = routeModel(taskType, 'Local Only', settings, 'stage1');
        routing.provider   = localRouting.provider;
        routing.model      = localRouting.model;
        routing.cost_label = localRouting.cost_label;
        routing.cost_usd   = 0;
        routing.reason     = reason;
        routing.fallback   = true;
      }
    }

    // Determine prompt for this stage
    const prompt = stageNum === 1
      ? userPrompt
      : buildPolishPrompt(currentText, userPrompt, stageKey);

    let result;

    try {
      // Stage 1 workers: try OpenClaw first if provider is ollama
      if (stageNum === 1 && routing.provider === 'ollama') {
        if (openclawAvailable === null) {
          openclawAvailable = await serviceAlive('http://localhost:18789');
        }
        if (openclawAvailable) {
          result = await callOpenClaw(routing.model, systemPrompt, prompt);
          routing.provider = 'openclaw';
        }
      }

      if (!result) {
        result = await callProvider(routing, systemPrompt, prompt, settings);
      }
    } catch (err) {
      // On any error, try local ollama as last resort
      if (routing.provider !== 'ollama') {
        const primary = settings.primary_model || 'qwen3.5:9b';
        result = await callOllama(primary, systemPrompt, prompt, settings.ollama_port || 11434);
        routing.provider   = 'ollama';
        routing.model      = primary;
        routing.cost_label = 'Free';
        routing.cost_usd   = 0;
        routing.reason     = `API error (${err.message}) — fell back to local model`;
        routing.fallback   = true;
      } else {
        throw new Error(`Generation failed: ${err.message}. Is Ollama running?`);
      }
    }

    currentText  = result.text;
    totalTokens += result.tokens || 0;
    totalCost   += routing.cost_usd || 0;
    finalRouting = routing;

    stagesRun.push({
      stage:      stageKey,
      provider:   routing.provider,
      model:      routing.model,
      cost_label: routing.cost_label,
      tokens:     result.tokens || 0,
    });

    // Track spend if non-free
    if (routing.cost_usd > 0) {
      trackSpend(routing.cost_usd, routing.cost_label);
    }
  }

  if (!finalRouting) {
    throw new Error('No routing resolved — check settings and try again.');
  }

  // Get updated spend after tracking
  const spendAfter = getSpend(settings);

  return {
    result:      currentText,
    model_used:  finalRouting.model,
    provider:    finalRouting.provider,
    cost_label:  finalRouting.cost_label,
    cost_usd:    parseFloat(totalCost.toFixed(6)),
    tokens:      totalTokens,
    reason:      finalRouting.reason,
    cheaper_alt: finalRouting.cheaper_alt,
    stages_run:  stagesRun,
    spend:       spendAfter,
  };
}

// ── Key validation ────────────────────────────────────────────────────────────

async function testApiKey(provider, key) {
  const start = Date.now();
  try {
    if (provider === 'openai') {
      const res = await fetch('https://api.openai.com/v1/models', {
        headers: { Authorization: `Bearer ${key}` },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      return { valid: true, model_count: data.data?.length || 0, latency_ms: Date.now() - start };
    }
    if (provider === 'anthropic') {
      const res = await fetch('https://api.anthropic.com/v1/models', {
        headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01' },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      return { valid: true, model_count: data.models?.length || data.data?.length || 0, latency_ms: Date.now() - start };
    }
    if (provider === 'groq') {
      const res = await fetch('https://api.groq.com/openai/v1/models', {
        headers: { Authorization: `Bearer ${key}` },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      return { valid: true, model_count: data.data?.length || 0, latency_ms: Date.now() - start };
    }
    throw new Error(`Unknown provider: ${provider}`);
  } catch (err) {
    return { valid: false, error: err.message, latency_ms: Date.now() - start };
  }
}

module.exports = { generate, testApiKey, serviceAlive };
