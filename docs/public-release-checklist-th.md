# เช็กลิสต์ปล่อย ReJoy สู่สาธารณะ

## ต้องทำก่อนส่งร้านแอป

- สร้างและสำรอง Android upload keystore ด้วย `rejoy/tool/create_android_keystore.ps1`
- สร้าง App Bundle ด้วย `rejoy/tool/build_android_release.ps1`
- ใช้ backend แบบ always-on ไม่ใช่ free instance ที่ sleep
- จำกัด `CORS_ORIGIN` ให้เป็นโดเมนที่ใช้งานจริงแทน `*`
- ใส่ Privacy Policy URL ใน Play Console และให้เข้าถึงจากในแอป
- กรอก Google Play Data safety ให้ตรงกับข้อมูลจริง รวมสุขภาพ ตำแหน่ง บัญชี และข้อความแชท
- เพิ่มช่องทางขอลบบัญชี/ข้อมูลที่ติดต่อผู้พัฒนาได้จริง
- ทดสอบ login, Companion Chat, SOS location, PDF และ secure storage บน Android จริงอย่างน้อย 2 รุ่น
- ทดลองรายงาน PDF กับผู้เชี่ยวชาญ และตรวจทุกข้อความว่าไม่สื่อว่าแอปวินิจฉัยหรือสั่งยา
- ตั้ง external monitoring/alerting สำหรับ availability และ error rate

## ขอบเขต Gemini ที่ห้ามข้าม

- ใช้เป็นเพื่อนคุยเรื่องชีวิตประจำวันเท่านั้น
- ไม่ใช้ให้คะแนน PHQ-9 หรือวินิจฉัย
- ไม่ใช้สั่งยา ปรับยา หรือแนะนำให้หยุดยา
- คำเสี่ยงต้องถูกสกัดก่อนส่ง AI และพาไปหน้า SOS

## หมายเหตุเรื่อง hosting

โค้ดทำให้ backend เสถียรและตรวจสถานะได้ แต่ไม่สามารถบังคับ Render Free ไม่ให้ sleep ได้ หากต้องใช้งานสาธารณะจริงต้องเปลี่ยนเป็น instance แบบ always-on หรือผู้ให้บริการที่รับประกันการทำงานต่อเนื่อง
