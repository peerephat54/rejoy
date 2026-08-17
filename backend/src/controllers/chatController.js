const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";
const DEFAULT_GEMINI_TIMEOUT_MS = 8000;
const { getDailyTopic } = require("../services/dailyConversationTopics");

const HOTLINE_TEXT =
  "ถ้าตอนนี้ไม่ปลอดภัยหรืออยากคุยกับคนจริง ๆ โทรสายด่วนสุขภาพจิต 1323 ได้เลยนะ เขามีคนรับฟังและช่วยประคองสถานการณ์";

const SAFETY_PROMPT = `
You are ReJoy Buddy, a supportive Thai friend for everyday conversation. You are not a doctor, therapist, diagnosis tool, or emergency service.
Use natural, warm Thai suitable for a teenager. Sound like a caring friend who listens, not a lecturer. Keep each reply concise and easy to read in a mobile chat bubble.
Stay with ordinary daily life. Never turn the conversation into philosophy, motivational preaching, a clinical interview, or a PHQ-9 assessment. The app handles screening separately with deterministic rules.
Validate the person's feeling without claiming to know exactly how they feel. Do not shame, pressure, guilt, reward dependency, or promise that everything will be fine.
Ask no more than one gentle and practical follow-up question. When helpful, offer one tiny optional next step using words such as "ถ้าไหว" or "ลองดูไหม".
Never diagnose a disease, label a risk level, interpret a clinical score, prescribe medicine, or advise starting, stopping, increasing, decreasing, or changing medication.
If medicine is mentioned, explain briefly that medicine decisions belong to a doctor or pharmacist and offer to help the user write a question for them.
If immediate self-harm danger appears, prioritize staying near a trusted person and contacting Thailand mental-health hotline 1323 or local emergency services. Do not continue normal conversation.
Reply in Thai only.
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
    const safeTopic = String(topic || getDailyTopic()).slice(0, 160);
    const contents = [
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
          systemInstruction: {
            parts: [
              {
                text: `${SAFETY_PROMPT}\nหัวข้อชีวิตประจำวันของวันนี้คือ: ${safeTopic}\nเชื่อมบทสนทนากับหัวข้อนี้เมื่อเหมาะสม โดยไม่ฝืนเปลี่ยนเรื่องที่ผู้ใช้กำลังเล่า`,
              },
            ],
          },
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
      topic,
    } = req.body;
    const dailyTopic = String(topic || getDailyTopic()).slice(0, 160);

    if (detectRedFlag(message)) {
      return res.json(safetyInterceptionReply());
    }

    const config = getGeminiConfig();
    if (!config.configured) {
      return res.json({
        provider: "fallback",
        geminiConfigured: false,
        topic: dailyTopic,
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
        topic: dailyTopic,
      });

      return res.json({
        provider: "gemini",
        model: config.model,
        geminiConfigured: true,
        topic: dailyTopic,
        message: aiText || fallbackReply(message),
      });
    } catch (error) {
      console.warn("Gemini fallback:", error.message, error.detail || "");
      return res.json({
        provider: "fallback",
        geminiConfigured: true,
        topic: dailyTopic,
        fallbackReason: error.name === "AbortError" ? "timeout" : "provider_error",
        message: fallbackReply(message),
      });
    }
  } catch (error) {
    return next(error);
  }
}

function dailyTopic(req, res) {
  const requestedDate = req.query.date ? new Date(req.query.date) : new Date();
  const date = Number.isNaN(requestedDate.getTime()) ? new Date() : requestedDate;
  res.json({
    date: date.toISOString().slice(0, 10),
    topic: getDailyTopic(date),
  });
}

module.exports = {
  companionChat,
  dailyTopic,
  detectRedFlag,
  fallbackReply,
  getGeminiConfig,
};
