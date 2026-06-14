const OpenAI = require("openai");

const clients = {};

function getClient(provider) {
  if (!clients[provider]) {
    const options = { apiKey: process.env[`${provider.toUpperCase()}_API_KEY`] };
    if (provider === "xai") options.baseURL = "https://api.x.ai/v1";
    clients[provider] = new OpenAI(options);
  }
  return clients[provider];
}

async function generateOpenAI({ provider, model, prompt, systemPrompt, maxTokens = 4096 }) {
  const messages = [];
  if (systemPrompt) messages.push({ role: "system", content: systemPrompt });
  messages.push({ role: "user", content: prompt });

  const response = await getClient(provider).chat.completions.create({
    model,
    messages,
    max_tokens: maxTokens,
  });

  return response.choices[0].message.content;
}

module.exports = { generateOpenAI };
