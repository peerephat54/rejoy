import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const revisionDate = '17 สิงหาคม 2569';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('นโยบายความเป็นส่วนตัว')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F6F4), Color(0xFFFFF8EC)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFD7ECE7)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'นโยบายความเป็นส่วนตัว ReJoy',
                        style: TextStyle(
                          color: Color(0xFF17343C),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ปรับปรุงล่าสุด $revisionDate',
                        style: TextStyle(color: Color(0xFF607A81)),
                      ),
                      SizedBox(height: 20),
                      _PolicySection(
                        title: '1. ข้อมูลที่แอปใช้',
                        body:
                            'ReJoy ใช้ข้อมูลบัญชี โปรไฟล์สุขภาพที่ผู้ใช้กรอก บันทึกอารมณ์ คะแนนคัดกรอง PHQ-9 การทำภารกิจ บันทึกความในใจ เหตุการณ์ SOS และตำแหน่งที่ผู้ใช้อนุญาตเฉพาะเมื่อใช้ระบบค้นหาสถานพยาบาลใกล้เคียง',
                      ),
                      _PolicySection(
                        title: '2. จุดประสงค์ของการใช้ข้อมูล',
                        body:
                            'ข้อมูลใช้เพื่อแสดงแนวโน้มส่วนตัว ปรับบรรยากาศเกาะ บันทึกความคืบหน้าของกิจกรรม สร้างรายงานที่ผู้ใช้เลือกส่งให้แพทย์ และช่วยให้บุคลากรที่ได้รับมอบหมายเตรียมคำถามก่อนพบผู้ใช้',
                      ),
                      _PolicySection(
                        title: '3. ขอบเขตของ Gemini AI',
                        body:
                            'เฉพาะข้อความที่ผู้ใช้กดส่งในหน้าแชทเท่านั้นที่อาจถูกส่งผ่าน backend ไปยัง Gemini เพื่อสร้างคำตอบแบบเพื่อนคุย ระบบจะตรวจคำเสี่ยงในเครื่องก่อนส่ง และไม่ใช้ Gemini วินิจฉัยโรค ให้คะแนน PHQ-9 ตัดสินระดับความเสี่ยง หรือแนะนำการใช้ยา',
                      ),
                      _PolicySection(
                        title: '4. การเปิดเผยและการรักษาความปลอดภัย',
                        body:
                            'ข้อมูลไม่ควรถูกขายเพื่อโฆษณา แพทย์เห็นเฉพาะผู้ป่วยที่ได้รับมอบหมายและเห็นข้อมูลสรุปตามสิทธิ์ รหัสผ่านถูกแฮช การเชื่อมต่อ cloud ใช้ HTTPS และ token ถูกเก็บในพื้นที่ปลอดภัยของอุปกรณ์ ทั้งนี้ผู้ใช้ควรดูแลไฟล์ PDF และภาพหน้าจอที่ส่งออกด้วย',
                      ),
                      _PolicySection(
                        title: '5. สิทธิ์ของผู้ใช้',
                        body:
                            'ผู้ใช้มีสิทธิ์ขอดู แก้ไข ส่งออก หรือลบบัญชีและข้อมูลของตน การเปิดตำแหน่งเป็นทางเลือกและปิดได้จากการตั้งค่าของโทรศัพท์ ช่องทางติดต่อผู้พัฒนาให้ยึดตามข้อมูลติดต่อที่แสดงในหน้าร้านแอปหรือเอกสารโครงการอย่างเป็นทางการ',
                      ),
                      _PolicySection(
                        title: '6. ข้อจำกัดทางการแพทย์',
                        body:
                            'ReJoy เป็นเครื่องมือสนับสนุนการติดตามและเตรียมข้อมูล ไม่วินิจฉัยโรค ไม่สั่งยา ไม่ปรับยา และไม่ทดแทนแพทย์ นักจิตวิทยา หรือบริการฉุกเฉิน หากรู้สึกไม่ปลอดภัยให้ติดต่อคนที่ไว้ใจ สายด่วนสุขภาพจิต 1323 หรือบริการฉุกเฉินในพื้นที่ทันที',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF17343C),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF405F66),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
