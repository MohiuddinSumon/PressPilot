const http = require("http");
const https = require("https");

async function generateOllama({ model, prompt, systemPrompt, maxTokens = 4096 }) {
  const baseUrl = process.env.OLLAMA_URL || "http://ollama:11434";
  const url = new URL("/api/generate", baseUrl);

  const body = JSON.stringify({
    model,
    prompt: systemPrompt ? `${systemPrompt}\n\n${prompt}` : prompt,
    stream: false,
    options: { num_predict: maxTokens },
  });

  return new Promise((resolve, reject) => {
    const lib = url.protocol === "https:" ? https : http;
    const req = lib.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname,
        method: "POST",
        headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            const parsed = JSON.parse(data);
            if (parsed.error) return reject(new Error(parsed.error));
            resolve(parsed.response);
          } catch (e) {
            reject(new Error(`Ollama parse error: ${e.message}`));
          }
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

module.exports = { generateOllama };
