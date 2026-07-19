const Quest = require("../models/Quest");

const defaultQuests = [
  {
    name: "หายใจใต้ผ้าห่ม 3 รอบ",
    description:
      "อยู่ตรงที่เดิมได้เลยนะ ค่อย ๆ หายใจเข้า แล้วผ่อนออก 3 รอบ แค่นี้ก็นับว่าเริ่มดูแลตัวเองแล้ว",
    energyLevel: "low",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "fox-01",
    color: "#8FC7A5",
    isActive: true,
  },
  {
    name: "จิบน้ำแบบไม่ต้องรีบ",
    description:
      "หยิบน้ำใกล้ตัวแล้วจิบช้า ๆ 3-5 คำ ระหว่างนั้นลองสังเกตความเย็นหรือสัมผัสของแก้ว",
    energyLevel: "rest",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "otter-02",
    color: "#8FD3CE",
    isActive: true,
  },
  {
    name: "ขยับปลายนิ้วปลุกพลัง",
    description:
      "ขยับนิ้วมือ นิ้วเท้า หรือยืดไหล่เบา ๆ 20 วินาที เพื่อบอกสมองว่าเรายังเริ่มจากจุดเล็ก ๆ ได้",
    energyLevel: "low",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "rabbit-03",
    color: "#F3B8C8",
    isActive: true,
  },
  {
    name: "เปิดม่านรับแสงนิดเดียว",
    description:
      "ถ้าไหว ลองเปิดม่านหรือมองออกไปนอกหน้าต่าง 30 วินาที ไม่ต้องทำอะไรต่อ แค่ให้ร่างกายรู้ว่าวันเริ่มแล้ว",
    energyLevel: "low",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "owl-04",
    color: "#B9B3E8",
    isActive: true,
  },
  {
    name: "เก็บของหนึ่งชิ้นกลับที่เดิม",
    description:
      "เลือกของแค่ 1 ชิ้นแล้ววางกลับที่เดิม ถ้าทำได้มากกว่านั้นคือโบนัส แต่หนึ่งชิ้นก็พอแล้ว",
    energyLevel: "medium",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "deer-05",
    color: "#D7B08A",
    isActive: true,
  },
  {
    name: "เขียนประโยคใจดีกับตัวเอง",
    description:
      "เขียนสั้น ๆ หนึ่งประโยคเหมือนพูดกับเพื่อนที่เหนื่อย เช่น วันนี้ทำได้เท่าที่ไหวก็พอ",
    energyLevel: "medium",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "seal-06",
    color: "#A8C8E8",
    isActive: true,
  },
  {
    name: "เดินช้า ๆ 1 นาที",
    description:
      "เดินในห้องหรือหน้าบ้านช้า ๆ 1 นาที ถ้าร่างกายบอกว่าเหนื่อย ให้หยุดได้ทันทีโดยไม่ต้องรู้สึกผิด",
    energyLevel: "medium",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "cat-07",
    color: "#F2C47E",
    isActive: true,
  },
  {
    name: "เลือกงานเล็กที่สุดหนึ่งอย่าง",
    description:
      "มองรายการสิ่งที่ต้องทำ แล้วเลือกแค่อย่างที่เล็กที่สุด ทำ 5 นาทีพอ ไม่ต้องจบทั้งหมด",
    energyLevel: "high",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "lion-08",
    color: "#E9A35F",
    isActive: true,
  },
  {
    name: "ส่งข้อความหาคนที่ไว้ใจ",
    description:
      "พิมพ์สั้น ๆ ว่า วันนี้เราเหนื่อยนิดหน่อยนะ ไม่จำเป็นต้องอธิบายยาว แค่เปิดประตูให้มีคนอยู่ข้าง ๆ",
    energyLevel: "high",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "whale-09",
    color: "#86B7D9",
    isActive: true,
  },
  {
    name: "เตรียมพื้นที่พักคืนนี้",
    description:
      "จัดหมอน ผ้าห่ม หรือน้ำดื่มไว้ใกล้ตัว เพื่อให้ตอนกลางคืนปลอดภัยและง่ายขึ้นอีกนิด",
    energyLevel: "rest",
    reward: "ปลดล็อกสัตว์พาสเทล",
    animalId: "turtle-10",
    color: "#9CCB8A",
    isActive: true,
  },
];

const obsoleteQuestNames = [
  "Breathe under the blanket",
  "Drink a glass of water",
  "Tidy one corner",
  "Write one kind sentence",
  "Finish one important task",
];

async function seedDefaultQuests() {
  let inserted = 0;

  await Quest.updateMany(
    { name: { $in: obsoleteQuestNames } },
    { $set: { isActive: false } },
  );

  for (const quest of defaultQuests) {
    const result = await Quest.updateOne(
      { animalId: quest.animalId },
      { $set: quest },
      { upsert: true },
    );

    if (result.upsertedCount > 0) {
      inserted += result.upsertedCount;
    }
  }

  return { inserted };
}

module.exports = {
  seedDefaultQuests,
};
