const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";
const DEFAULT_GEMINI_TIMEOUT_MS = 8000;

const HOTLINE_TEXT =
  "ถ้าตอนนี้ไม่ปลอดภัยหรืออยากคุยกับคนจริง ๆ โทรสายด่วนสุขภาพจิต 1323 ได้เลยนะ เขามีคนรับฟังและช่วยประคองสถานการณ์";

const SAFETY_PROMPT = `
You are ReJoy Buddy, a gentle Thai teen mental-health companion, not a doctor.
Speak like a caring friend: warm, concise, non-judgmental, and guilt-free.
You may support reflection and daily check-ins, but you must not diagnose.
You must not prescribe, stop, increase, decrease, or change medication.
If medication is mentioned, say you cannot decide about medicine and suggest asking a doctor, pharmacist, qualified expert, or hotline 1323.
If the user mentions immediate self-harm danger, encourage staying near a trusted person and contacting hotline 1323 immediately.
Ask at most one soft follow-up question.
Keep the reply in Thai and keep it short enough for a mobile chat bubble.
`;

const PLACEHOLDER_KEYS = new Set([
  "",
  "your_gemini_api_key_here",
  "demo-no-gemini",
  "demo_no_gemini",
  "none",
  "null",
  "undefined",
]);

const RED_FLAG_PATTERNS = [
  /อยากตาย/i,
  /ฆ่าตัวตาย/i,
  /ทำร้ายตัวเอง/i,
  /ไม่อยากอยู่/i,
  /อยากหายไปตลอด/i,
  /suicide/i,
  /kill myself/i,
  /end my life/i,
  /self[-\s]?harm/i,
];

const MEDICATION_PATTERNS = [
  /ยา/i,
  /หยุดยา/i,
  /เพิ่มยา/i,
  /ลดยา/i,
  /กินยา/i,
  /med/i,
  /medicine/i,
  /dose/i,
];

function getGeminiConfig() {
  const apiKey = String(process.env.GEMINI_API_KEY || "").trim();
  const normalizedKey = apiKey.toLowerCase();
  const configured = apiKey.length > 0 && !PLACEHOLDER_KEYS.has(normalizedKey);

  return {
    apiKey,
    configured,
    model: String(process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL).trim(),
    timeoutMs: Number(process.env.GEMINI_TIMEOUT_MS || DEFAULT_GEMINI_TIMEOUT_MS),
  };
}

function hasPattern(text, patterns) {
  return patterns.some((pattern) => pattern.test(text));
}

function detectRedFlag(message = "") {
  return hasPattern(String(message), RED_FLAG_PATTERNS);
}

function detectMedicationTopic(message = "") {
  return hasPattern(String(message), MEDICATION_PATTERNS);
}

function safetyInterceptionReply() {
  return {
    provider: "safety-intercept",
    riskLevel: "red",
    blockedAi: true,
    message:
      "เราห่วงความปลอดภัยของคุณมากนะ ข้อความนี้จะไม่ถูกส่งต่อไป AI ตอนนี้ขอให้ขยับไปอยู่ใกล้คนที่ไว้ใจได้ หรือโทร 1323 เพื่อให้มีคนจริง ๆ อยู่กับคุณทันที",
  };
}

function fallbackReply(message = "") {
  const text = String(message);

  if (detectRedFlag(text)) {
    return safetyInterceptionReply().message;
  }

  if (detectMedicationTopic(text)) {
    return "เรื่องยาเราไม่อยากเดาแทนหมอนะ แต่ช่วยจดคำถามนี้ให้เอาไปถามแพทย์ เภสัชกร หรือสายด่วน 1323 ได้ ถ้าอยากเล่าเพิ่มว่าอาการเป็นยังไง เราจะช่วยเรียบเรียงให้พูดง่ายขึ้น";
  }

  return "เราได้ยินนะ ขอบคุณที่เล่าให้ฟัง ลองเล่าเพิ่มได้ไหมว่าส่วนไหนของเรื่องนี้หนักกับใจที่สุด เราจะค่อย ๆ อยู่ตรงนี้กับคุณ";
}

function normalizeHistory(history) {
  if (!Array.isArray(history)) return [];

  return history
    .slice(-8)
    .map((item) => ({
      role: item?.role === "bot" || item?.role === "model" ? "model" : "user",
      parts: [{ text: String(item?.text || "").slice(0, 1200) }],
    }))
    .filter((item) => item.parts[0].text.trim().length > 0);
}

async function callGemini({ apiKey, model, timeoutMs, message, history, topic }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const contents = [
      {
        role: "user",
        parts: [
          {
            text: `${SAFETY_PROMPT}
Today's daily-life conversation topic is: ${String(topic)}.
Keep replies grounded in this ordinary-life topic when possible.
If you ask a follow-up, make it feel like a friend noticing daily life, not a clinical questionnaire.`,
          },
        ],
      },
      ...normalizeHistory(history),
      {
        role: "user",
        parts: [{ text: String(message).slice(0, 2000) }],
      },
    ];

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
        model,
      )}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          contents,
          generationConfig: {
            temperature: 0.55,
            topP: 0.9,
            maxOutputTokens: 180,
          },
          safetySettings: [
            { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          ],
        }),
        signal: controller.signal,
      },
    );

    if (!response.ok) {
      const body = await response.text().catch(() => "");
      const error = new Error(`Gemini request failed (${response.status})`);
      error.detail = body.slice(0, 300);
      throw error;
    }

    const data = await response.json();
    return data.candidates?.[0]?.content?.parts
      ?.map((part) => part.text || "")
      .join("\n")
      .trim();
  } finally {
    clearTimeout(timeout);
  }
}

async function companionChat(req, res, next) {
  try {
    const {
      message = "",
      history = [],
      topic = "ชีวิตประจำวันวันนี้",
    } = req.body;

    if (detectRedFlag(message)) {
      return res.json(safetyInterceptionReply());
    }

    const config = getGeminiConfig();
    if (!config.configured) {
      return res.json({
        provider: "fallback",
        geminiConfigured: false,
        message: fallbackReply(message),
      });
    }

    try {
      const aiText = await callGemini({
        apiKey: config.apiKey,
        model: config.model,
        timeoutMs: config.timeoutMs,
        message,
        history,
        topic,
      });

      return res.json({
        provider: "gemini",
        model: config.model,
        geminiConfigured: true,
        message: aiText || fallbackReply(message),
      });
    } catch (error) {
      console.warn("Gemini fallback:", error.message, error.detail || "");
      return res.json({
        provider: "fallback",
        geminiConfigured: true,
        fallbackReason: error.name === "AbortError" ? "timeout" : "provider_error",
        message: fallbackReply(message),
      });
    }
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  companionChat,
  detectRedFlag,
  fallbackReply,
  getGeminiConfig,
};
