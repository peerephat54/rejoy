const HOTLINE_TEXT =
  "ถ้าตอนนี้ไม่ปลอดภัยหรืออยากคุยกับคนจริง ๆ โทรสายด่วนสุขภาพจิต 1323 ได้เลยนะ เขามีคนรับฟังและช่วยประคองสถานการณ์";

const SAFETY_PROMPT = `
You are ReJoy, a gentle Thai teen companion, not a doctor.
Speak like a caring friend who is present, warm, and not dramatic.
After the daily screening is done, continue normal supportive conversation.
Do not diagnose. Do not prescribe, recommend, stop, increase, decrease, or change medication.
If medication is mentioned, say you cannot decide about medicine and suggest asking a doctor, pharmacist, qualified expert, or hotline 1323.
If the user mentions immediate self-harm danger, encourage staying near a trusted person and contacting hotline 1323 immediately.
Ask at most one soft follow-up question.
Keep replies short, Thai, non-judgmental, and guilt-free.
`;

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

function hasAny(text, signals) {
  return signals.some((signal) => text.includes(signal));
}

function detectRedFlag(message = "") {
  const text = String(message);
  return RED_FLAG_PATTERNS.some((pattern) => pattern.test(text));
}

function safetyInterceptionReply() {
  return {
    provider: "safety-intercept",
    riskLevel: "red",
    blockedAi: true,
    message:
      "เราเป็นห่วงความปลอดภัยของคุณมากนะ ข้อความนี้จะไม่ถูกส่งต่อไป AI ตอนนี้ขอให้ขยับไปอยู่ใกล้คนที่ไว้ใจได้ หรือโทร 1323 เพื่อให้มีคนจริง ๆ อยู่กับคุณทันที",
  };
}

function fallbackReply(message = "") {
  const normalized = String(message).toLowerCase();

  if (detectRedFlag(normalized)) {
    return safetyInterceptionReply().message;
  }

  if (
    hasAny(normalized, [
      "ยา",
      "หยุดยา",
      "เพิ่มยา",
      "ลดยา",
      "กินยา",
      "med",
      "medicine",
    ])
  ) {
    return "เรื่องยาเราไม่อยากเดาแทนหมอนะ แต่เราช่วยจดคำถามนี้ให้เอาไปถามแพทย์ เภสัชกร หรือสายด่วน 1323 ได้ ถ้าต้องการ เดี๋ยวเราช่วยเรียบเรียงให้พูดง่ายขึ้น";
  }

  if (hasAny(normalized, ["ผู้เชี่ยวชาญ", "สายด่วน", "หมอ", "ปรึกษา"])) {
    return `คำถามนี้เอาไปถามผู้เชี่ยวชาญได้เลยนะ ลองจดสั้น ๆ ว่า "ช่วงนี้ฉันรู้สึกแบบนี้ เกิดบ่อยแค่ไหน และกระทบการนอน/กิน/เรียนยังไง" ${HOTLINE_TEXT}`;
  }

  return "เราได้ยินนะ ขอบคุณที่เล่าให้ฟัง เล่าเพิ่มได้เลยว่าส่วนไหนของเรื่องนี้หนักกับใจที่สุด เราจะค่อย ๆ อยู่ตรงนี้กับคุณ";
}

async function companionChat(req, res, next) {
  try {
    const {
      message = "",
      history = [],
      topic = "ชีวิตประจำวันวันนี้",
    } = req.body;
    const apiKey = process.env.GEMINI_API_KEY;

    if (detectRedFlag(message)) {
      return res.json(safetyInterceptionReply());
    }

    if (!apiKey) {
      return res.json({
        provider: "fallback",
        message: fallbackReply(message),
      });
    }

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
      ...history.slice(-8).map((item) => ({
        role: item.role === "bot" ? "model" : "user",
        parts: [{ text: String(item.text ?? "") }],
      })),
      {
        role: "user",
        parts: [{ text: String(message) }],
      },
    ];

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          contents,
          generationConfig: {
            temperature: 0.55,
            maxOutputTokens: 180,
          },
        }),
      },
    );

    if (!response.ok) {
      return res.json({
        provider: "fallback",
        message: fallbackReply(message),
      });
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

    return res.json({
      provider: "gemini",
      message: text || fallbackReply(message),
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  companionChat,
};
