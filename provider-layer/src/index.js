const express = require("express");
const { generate } = require("./router");

const app = express();
app.use(express.json({ limit: "4mb" }));

// Health check
app.get("/health", (_req, res) => res.json({ status: "ok" }));

// POST /generate
// Body: { task: "scoring"|"research"|"draft", prompt: string, systemPrompt?: string, maxTokens?: number }
// Returns: { text: string, provider: string, model: string }
app.post("/generate", async (req, res) => {
  const { task, prompt, systemPrompt, maxTokens } = req.body;

  if (!task || !prompt) {
    return res.status(400).json({ error: "task and prompt are required" });
  }

  if (!["scoring", "research", "draft"].includes(task)) {
    return res.status(400).json({ error: "task must be scoring, research, or draft" });
  }

  try {
    const result = await generate({ task, prompt, systemPrompt, maxTokens });
    res.json(result);
  } catch (err) {
    console.error(`[provider-layer] Error for task=${task}:`, err.message);
    res.status(502).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3100;
app.listen(PORT, () => {
  console.log(`[provider-layer] Listening on :${PORT}`);
  logActiveProviders();
});

function logActiveProviders() {
  const providers = ["anthropic", "openai", "xai", "gemini", "ollama"];
  const active = providers.filter((p) => {
    if (p === "ollama") return !!process.env.OLLAMA_URL;
    return !!process.env[`${p.toUpperCase()}_API_KEY`];
  });
  console.log(`[provider-layer] Active providers: ${active.join(", ") || "NONE — set API keys in .env"}`);
}
