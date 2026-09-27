const windows = new Map();

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" }
  });
}

function rateLimited(request, limit = 90) {
  const client = request.headers.get("CF-Connecting-IP") || "unknown";
  const minute = Math.floor(Date.now() / 60000);
  const key = `${client}:${minute}`;
  const count = (windows.get(key) || 0) + 1;
  windows.set(key, count);
  if (windows.size > 10000) windows.clear();
  return count > limit;
}

function allowedGoalPath(path) {
  return [
    /^\/fixtures(?:\/.*)?$/,
    /^\/leagues(?:\/.*)?$/,
    /^\/teams(?:\/.*)?$/,
    /^\/videos(?:\/.*)?$/,
    /^\/news(?:\/.*)?$/
  ].some((pattern) => pattern.test(path));
}

async function proxyGoal(request, env, url) {
  const goalPath = url.pathname.slice("/v1/goal".length) || "/";
  if (!allowedGoalPath(goalPath)) return json({ error: { message: "Unsupported GOAL resource." } }, 404);
  const upstream = new URL(`https://api.goal-api.com/v1${goalPath}`);
  upstream.search = url.search;
  const response = await fetch(upstream, {
    method: "GET",
    headers: { Authorization: `Bearer ${env.GOAL_API_KEY}`, Accept: "application/json" }
  });
  return new Response(response.body, {
    status: response.status,
    headers: { "content-type": response.headers.get("content-type") || "application/json" }
  });
}

async function geminiCommentary(request, env) {
  const body = await request.json();
  if (typeof body.question !== "string" || typeof body.context !== "string" || body.question.length > 1000 || body.context.length > 30000) {
    return json({ error: { message: "Invalid commentary request." } }, 400);
  }
  const rules = "You are Tempo, a concise football analyst. Use only facts and numbers explicitly supplied in the context. Never estimate or invent numerical football facts. If evidence is missing, clearly say it is unavailable. Distinguish observation from inference.";
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_MODEL || "gemini-3.5-flash-lite"}:generateContent`, {
    method: "POST",
    headers: { "x-goog-api-key": env.GEMINI_API_KEY, "content-type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: rules }] },
      contents: [{ role: "user", parts: [{ text: `${body.context}\n\nQuestion: ${body.question}` }] }],
      generationConfig: { temperature: 0.2, maxOutputTokens: 700 }
    })
  });
  const payload = await response.json();
  if (!response.ok) return json({ error: { message: payload?.error?.message || "AI provider request failed." } }, response.status);
  const answer = payload?.candidates?.[0]?.content?.parts?.map((part) => part.text || "").join("\n").trim();
  return answer ? json({ answer }) : json({ error: { message: "AI provider returned no answer." } }, 502);
}

export default {
  async fetch(request, env) {
    if (rateLimited(request)) return json({ error: { message: "Rate limit exceeded." } }, 429);
    const url = new URL(request.url);
    try {
      if (request.method === "GET" && url.pathname.startsWith("/v1/goal/")) return await proxyGoal(request, env, url);
      if (request.method === "POST" && url.pathname === "/v1/ai/commentary") return await geminiCommentary(request, env);
      if (request.method === "GET" && url.pathname === "/health") return json({ status: "ok" });
      return json({ error: { message: "Not found." } }, 404);
    } catch {
      return json({ error: { message: "Upstream service unavailable." } }, 502);
    }
  }
};
