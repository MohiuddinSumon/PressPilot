const { generateAnthropic } = require("./providers/anthropic");
const { generateOpenAI } = require("./providers/openai");
const { generateGemini } = require("./providers/gemini");
const { generateOllama } = require("./providers/ollama");

// Map provider names to generator functions
const PROVIDERS = {
  anthropic: generateAnthropic,
  openai: generateOpenAI,
  xai: generateOpenAI,  // xAI uses OpenAI-compatible API
  gemini: generateGemini,
  ollama: generateOllama,
};

// Default models per provider per task tier
const DEFAULT_MODELS = {
  anthropic: {
    scoring: process.env.MODEL_ANTHROPIC_SCORING || "claude-haiku-4-5-20251001",
    research: process.env.MODEL_ANTHROPIC_SCORING || "claude-haiku-4-5-20251001",
    draft: process.env.MODEL_ANTHROPIC_DRAFT || "claude-sonnet-4-6",
  },
  openai: {
    scoring: process.env.MODEL_OPENAI_SCORING || "gpt-4o-mini",
    research: process.env.MODEL_OPENAI_SCORING || "gpt-4o-mini",
    draft: process.env.MODEL_OPENAI_DRAFT || "gpt-4o",
  },
  xai: {
    scoring: "grok-2",
    research: "grok-2",
    draft: "grok-2",
  },
  gemini: {
    scoring: process.env.MODEL_GEMINI_SCORING || "gemini-2.0-flash",
    research: process.env.MODEL_GEMINI_SCORING || "gemini-2.0-flash",
    draft: process.env.MODEL_GEMINI_DRAFT || "gemini-2.0-flash",
  },
  ollama: {
    scoring: process.env.MODEL_OLLAMA_SCORING || "llama3.2",
    research: process.env.MODEL_OLLAMA_SCORING || "llama3.2",
    draft: process.env.MODEL_OLLAMA_SCORING || "llama3.2",
  },
};

// Task → env var → ordered provider list
function getProviderOrder(task) {
  const envKey = `PROVIDER_${task.toUpperCase()}`;
  const raw = process.env[envKey] || "";
  return raw
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

function isProviderAvailable(provider) {
  if (provider === "ollama") return !!process.env.OLLAMA_URL;
  if (provider === "xai") return !!process.env.XAI_API_KEY;
  return !!process.env[`${provider.toUpperCase()}_API_KEY`];
}

async function generate({ task, prompt, systemPrompt, maxTokens }) {
  const order = getProviderOrder(task);

  // Filter to available providers in priority order
  const available = order.filter(isProviderAvailable);

  if (available.length === 0) {
    // Fallback: try any available provider
    const any = Object.keys(PROVIDERS).find(isProviderAvailable);
    if (!any) throw new Error("No LLM providers available. Set at least one API key in .env.");
    available.push(any);
  }

  let lastError;
  for (const provider of available) {
    const fn = PROVIDERS[provider];
    if (!fn) continue;

    const model = DEFAULT_MODELS[provider]?.[task];
    try {
      const text = await fn({ provider, model, prompt, systemPrompt, maxTokens });
      console.log(`[router] task=${task} provider=${provider} model=${model}`);
      return { text, provider, model };
    } catch (err) {
      console.warn(`[router] ${provider} failed for task=${task}: ${err.message}`);
      lastError = err;
    }
  }

  throw lastError || new Error("All providers failed");
}

module.exports = { generate };
