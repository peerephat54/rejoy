const Quest = require("../models/Quest");

const defaultQuests = [
  {
    name: "วางมือลงบนอกแล้วหายใจ 3 รอบ",
    description:
      "ไม่ต้องลุกจากที่เดิมก็ได้ แค่วางมือบนอกแล้วค่อย ๆ หายใจเข้าออก 3 รอบ ให้ร่างกายรู้ว่าตอนนี้ปลอดภัย",
    energyLevel: "rest",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "panda-01",
    color: "#8FD3CE",
    isActive: true,
  },
  {
    name: "จิบน้ำช้า ๆ 3 คำ",
    description:
      "หยิบน้ำใกล้ตัวแล้วจิบช้า ๆ สังเกตความเย็น รสชาติ หรือสัมผัสของแก้วแบบไม่ต้องรีบ",
    energyLevel: "rest",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "koala-02",
    color: "#A8C8E8",
    isActive: true,
  },
  {
    name: "ขยับปลายนิ้วปลุกตัวเองเบา ๆ",
    description:
      "ขยับนิ้วมือ นิ้วเท้า หรือไหล่เบา ๆ 20 วินาที เพื่อบอกสมองว่าเริ่มจากจุดเล็ก ๆ ได้",
    energyLevel: "rest",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "rabbit-03",
    color: "#F3B8C8",
    isActive: true,
  },
  {
    name: "ปล่อยไหล่ลง 10 วินาที",
    description:
      "ค่อย ๆ ลดไหล่ลงจากหู คลายกราม และปล่อยมือวางข้างตัว 10 วินาที แค่นี้ก็นับว่าเริ่มดูแลตัวเองแล้ว",
    energyLevel: "rest",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "seal-04",
    color: "#C9D8F2",
    isActive: true,
  },
  {
    name: "เปิดม่านรับแสงนิดเดียว",
    description:
      "ถ้าไหว ลองเปิดม่านหรือมองออกนอกหน้าต่าง 30 วินาที ไม่ต้องทำอะไรต่อ แค่ให้วันเริ่มเข้ามาเล็กน้อย",
    energyLevel: "low",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "owl-05",
    color: "#B9B3E8",
    isActive: true,
  },
  {
    name: "ล้างหน้าหรือเช็ดหน้าแบบอ่อนโยน",
    description:
      "ใช้น้ำหรือผ้าชุบน้ำเช็ดหน้าเบา ๆ เพื่อรีเซ็ตความรู้สึก ไม่ต้องแต่งตัวหรือทำขั้นตอนอื่นต่อก็ได้",
    energyLevel: "low",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "deer-06",
    color: "#9CCB8A",
    isActive: true,
  },
  {
    name: "เก็บของหนึ่งชิ้นกลับที่เดิม",
    description:
      "เลือกของแค่ 1 ชิ้นแล้ววางกลับที่เดิม ถ้าทำได้มากกว่านั้นคือโบนัส แต่หนึ่งชิ้นก็นับว่าสำเร็จแล้ว",
    energyLevel: "low",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "fox-07",
    color: "#D7B08A",
    isActive: true,
  },
  {
    name: "เขียนประโยคใจดีกับตัวเอง",
    description:
      "เขียนสั้น ๆ หนึ่งประโยคเหมือนพูดกับเพื่อนที่เหนื่อย เช่น วันนี้ทำได้เท่าที่ไหวก็พอ",
    energyLevel: "low",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "cat-08",
    color: "#F2C47E",
    isActive: true,
  },
  {
    name: "เลือกเพลงสงบหนึ่งเพลง",
    description:
      "เปิดเพลงที่ไม่เร่งอารมณ์หนึ่งเพลง แล้วนั่งฟังโดยไม่ต้องฝืนรู้สึกดี แค่ให้เสียงพยุงใจไว้สักครู่",
    energyLevel: "low",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "turtle-09",
    color: "#BFE5D8",
    isActive: true,
  },
  {
    name: "เดินช้า ๆ 1 นาที",
    description:
      "เดินในห้องหรือหน้าบ้านช้า ๆ 1 นาที ถ้าร่างกายบอกว่าเหนื่อยให้หยุดได้ทันทีโดยไม่ต้องรู้สึกผิด",
    energyLevel: "medium",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "otter-10",
    color: "#E9A35F",
    isActive: true,
  },
  {
    name: "จัดมุมพักให้ตัวเอง 2 นาที",
    description:
      "ขยับหมอน ผ้าห่ม หรือแก้วน้ำให้หยิบง่ายขึ้น เพื่อทำให้พื้นที่วันนี้ปลอดภัยและเป็นมิตรขึ้นนิดหนึ่ง",
    energyLevel: "medium",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "whale-11",
    color: "#86B7D9",
    isActive: true,
  },
  {
    name: "ส่งข้อความหาคนที่ไว้ใจ",
    description:
      "พิมพ์สั้น ๆ ว่าวันนี้เราเหนื่อยนิดหน่อยนะ ไม่จำเป็นต้องอธิบายยาว แค่เปิดประตูให้มีคนอยู่ข้าง ๆ",
    energyLevel: "medium",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "redpanda-12",
    color: "#F5C7B8",
    isActive: true,
  },
  {
    name: "อาบน้ำแบบไม่ต้องสมบูรณ์แบบ",
    description:
      "ถ้าไหว ลองอาบน้ำหรือเปลี่ยนเสื้อผ้าหนึ่งชิ้น เป้าหมายคือให้ตัวเบาขึ้น ไม่ใช่ต้องทำครบทุกขั้นตอน",
    energyLevel: "medium",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "capybara-13",
    color: "#F0D0A8",
    isActive: true,
  },
  {
    name: "เลือกงานเล็กที่สุดหนึ่งอย่าง",
    description:
      "มองรายการสิ่งที่ต้องทำ แล้วเลือกแค่อย่างที่เล็กที่สุด ทำ 5 นาทีพอ ไม่ต้องจบทั้งหมด",
    energyLevel: "high",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "lion-14",
    color: "#F4A66A",
    isActive: true,
  },
  {
    name: "เตรียมของสำหรับพรุ่งนี้หนึ่งอย่าง",
    description:
      "วางของที่ต้องใช้พรุ่งนี้ไว้จุดเดียว เช่น สมุด ยา หรือขวดน้ำ เพื่อลดแรงเริ่มต้นของวันถัดไป",
    energyLevel: "high",
    reward: "สัตว์พาสเทลจะค่อย ๆ แวะมาพักบนเกาะ",
    animalId: "bird-15",
    color: "#7EB9D6",
    isActive: true,
  },
  {
    name: "เควสจากหมอ: จดเวลานอนเมื่อคืน",
    description:
      "บันทึกคร่าว ๆ ว่าเข้านอนและตื่นประมาณกี่โมง เพื่อให้หมอเห็นแนวโน้มการนอนโดยไม่ต้องนึกย้อนหลัง",
    energyLevel: "low",
    reward: "เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น",
    animalId: "doctor-panda-16",
    color: "#BFE5D8",
    isActive: true,
  },
  {
    name: "เควสจากหมอ: เช็กผลข้างเคียงยา",
    description:
      "สำรวจตัวเองสั้น ๆ วันนี้ง่วงผิดปกติ มือสั่น คลื่นไส้ หรือใจสั่นไหม ถ้ามีให้จดไว้คุยกับผู้เชี่ยวชาญ",
    energyLevel: "medium",
    reward: "เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น",
    animalId: "doctor-koala-17",
    color: "#D9E7FF",
    isActive: true,
  },
  {
    name: "เควสจากหมอ: ทำ Safety Plan หนึ่งบรรทัด",
    description:
      "เขียนชื่อคนที่ติดต่อได้หนึ่งคน หรือสถานที่ที่ทำให้ปลอดภัยขึ้นหนึ่งที่ เผื่อวันที่ใจหนักมาก",
    energyLevel: "low",
    reward: "เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น",
    animalId: "doctor-redpanda-18",
    color: "#F5C7B8",
    isActive: true,
  },
  {
    name: "เควสจากหมอ: สังเกตความอยากอาหาร",
    description:
      "จดสั้น ๆ ว่าวันนี้กินได้น้อย ปกติ หรือมากกว่าปกติ ข้อมูลนี้ช่วยให้หมอถามต่อได้ตรงจุดขึ้น",
    energyLevel: "rest",
    reward: "เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น",
    animalId: "doctor-capybara-19",
    color: "#F0D0A8",
    isActive: true,
  },
  {
    name: "เควสจากหมอ: ให้คะแนนพลังงาน 0-10",
    description:
      "เลือกตัวเลขคร่าว ๆ ว่าพลังงานวันนี้อยู่เท่าไร ไม่ต้องแม่นมาก แค่ช่วยเห็นแนวโน้มของร่างกาย",
    energyLevel: "rest",
    reward: "เควสติดตามจากหมอ ช่วยให้การพบแพทย์ครั้งหน้าคุยได้เร็วขึ้น",
    animalId: "doctor-owl-20",
    color: "#C6D8F0",
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
  await Quest.updateMany(
    { name: { $in: obsoleteQuestNames } },
    { $set: { isActive: false } },
  );

  const result = await Quest.bulkWrite(
    defaultQuests.map((quest) => ({
      updateOne: {
        filter: { animalId: quest.animalId },
        update: { $set: quest },
        upsert: true,
      },
    })),
    { ordered: false },
  );

  await Quest.updateMany(
    { animalId: /^doctor-/ },
    { $set: { isActive: false } },
  );

  return { inserted: result.upsertedCount || 0 };
}

module.exports = {
  seedDefaultQuests,
};
