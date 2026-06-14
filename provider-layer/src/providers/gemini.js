// Gemini via OpenAI-compatible endpoint (google-generativeai SDK not needed)
const OpenAI = require("openai");

let client;
function getClient() {
  if (!client) {
    client = new OpenAI({
      apiKey: process.env.GEMINI_API_KEY,
      baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/",
    });
  }
  return client;
}

async function generateGemini({ model, prompt, systemPrompt, maxTokens = 4096 }) {
  const messages = [];
  if (systemPrompt) messages.push({ role: "system", content: systemPrompt });
  messages.push({ role: "user", content: prompt });

  const response = await getClient().chat.completions.create({
    model,
    messages,
    max_tokens: maxTokens,
  });

  return response.choices[0].message.content;
}

module.exports = { generateGemini };
