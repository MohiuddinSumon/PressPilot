const Anthropic = require("@anthropic-ai/sdk");

let client;
function getClient() {
  if (!client) client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  return client;
}

async function generateAnthropic({ model, prompt, systemPrompt, maxTokens = 4096 }) {
  const messages = [{ role: "user", content: prompt }];
  const params = { model, max_tokens: maxTokens, messages };
  if (systemPrompt) params.system = systemPrompt;

  const response = await getClient().messages.create(params);
  return response.content[0].text;
}

module.exports = { generateAnthropic };
