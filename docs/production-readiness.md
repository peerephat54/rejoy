# ReJoy Cloud Demo Readiness

เอกสารนี้คือแผนเอา ReJoy ไปพรีเซ็นต์แบบไม่ต้องพึ่งคอมเปิด backend ตลอดเวลา

## 1. Render Free สำหรับ backend

ใช้ Render เป็นตัวหลักสำหรับเดโม เพราะใช้ฟรีและง่ายสำหรับ Node.js

วิธีที่แนะนำที่สุด:

- Push โปรเจกต์นี้ขึ้น GitHub
- ใน Render เลือก New > Blueprint
- เลือก repo ของ ReJoy
- Render จะอ่านไฟล์ `render.yaml` ที่ root repo และสร้าง `rejoy-backend` ให้

ถ้าไม่ใช้ Blueprint ให้ตั้งค่า Web Service เองตามนี้:

ตั้งค่า Web Service:

- Runtime: Node
- Root Directory: `backend`
- Build Command: `npm install`
- Start Command: `npm start`
- Health Check Path: `/api/health`
- Plan: Free

Environment Variables ที่ต้องใส่ใน Render:

```text
NODE_ENV=production
PORT=10000
MONGODB_URI=<เอาจาก MongoDB Atlas>
JWT_SECRET=<สุ่มยาวอย่างน้อย 32 ตัวอักษร>
JWT_EXPIRES_IN=7d
GEMINI_API_KEY=<ใส่ถ้าจะโชว์ AI Gemini จริง>
CORS_ORIGIN=*
RATE_LIMIT_MAX=300
AUTH_RATE_LIMIT_MAX=20
HEALTH_CHECK_KEY=<สุ่มไว้ใช้เช็ก deep health แบบส่วนตัว>
MONGODB_MAX_POOL_SIZE=10
MONGODB_MIN_POOL_SIZE=1
MONGODB_MAX_IDLE_TIME_MS=60000
MONGODB_WAIT_QUEUE_TIMEOUT_MS=5000
MONGODB_SERVER_SELECTION_TIMEOUT_MS=8000
MONGODB_SOCKET_TIMEOUT_MS=30000
MONGODB_CONNECT_TIMEOUT_MS=10000
MONGODB_HEARTBEAT_FREQUENCY_MS=10000
```

หลัง deploy ได้ URL แล้ว ทดสอบ:

```powershell
Invoke-RestMethod "https://YOUR-REJOY-BACKEND.onrender.com/api/health"
```

## 2. MongoDB Atlas Free

ใช้ Atlas Free เป็นฐานข้อมูลหลักสำหรับ demo

สิ่งที่ต้องเช็ก:

- Database user สร้างแล้ว
- Password ใน `MONGODB_URI` ถูกต้อง
- Network Access อนุญาต IP ที่ใช้ deploy
- สำหรับ Render Free ถ้า IP เปลี่ยนง่าย ให้ใช้ `0.0.0.0/0` เฉพาะช่วง demo ได้ แต่หลังแข่งควรล็อกให้แคบลง

## 3. APK demo สำหรับมือถือ

หลังได้ Render URL ให้ build APK ด้วย:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\User\Documents\New project\scripts\build-rejoy-mobile-demo.ps1" -ApiBaseUrl "https://YOUR-REJOY-BACKEND.onrender.com"
```

ไฟล์ที่ใช้ส่งเข้าเครื่องมือถือ:

```text
C:\Users\User\Documents\New project\rejoy\build\app\outputs\flutter-apk\app-release.apk
```

หมายเหตุ:

- APK นี้เป็น release demo แต่ยัง sign ด้วย debug key ตามค่าเริ่มต้น
- ใช้พรีเซ็นต์/ทดสอบได้
- ถ้าจะขึ้น Play Store จริง ต้องทำ release signing ด้วย keystore ส่วนตัว

## 4. Flutter web/Chrome backup

Build web backup:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\User\Documents\New project\scripts\build-rejoy-web-demo.ps1" -ApiBaseUrl "https://YOUR-REJOY-BACKEND.onrender.com"
```

หรือเปิดแบบ dev:

```powershell
cd "C:\Users\User\Documents\New project\rejoy"
flutter run -d chrome --dart-define "REJOY_API_BASE_URL=https://YOUR-REJOY-BACKEND.onrender.com"
```

## 5. วิดีโอ demo 1-2 นาที

ควรถ่ายไว้เป็น backup แม้ระบบจริงพร้อมแล้ว

ลำดับวิดีโอที่แนะนำ:

- เปิดแอปและ login
- เห็นเกาะเปลี่ยนอารมณ์ตามข้อมูล
- เข้าแชท companion แบบถามทีละคำถาม
- ทำเควส Micro-CBT และปลดล็อกสัตว์
- เข้า SOS เห็น grounding + โรงพยาบาลใกล้ที่สุด
- เข้า Profile แล้วกด export PDF

## 6. Backend local backup

ใช้เมื่อ Render/อินเทอร์เน็ตมีปัญหาจริง ๆ

```powershell
cd "C:\Users\User\Documents\New project\backend"
& "C:\Program Files\nodejs\npm.cmd" run dev
```

แล้วเปิด Chrome:

```powershell
cd "C:\Users\User\Documents\New project\rejoy"
flutter run -d chrome
```

## ข้อจำกัดของแผนฟรี

- Render Free อาจ sleep ถ้าไม่มีคนเรียกใช้งาน ทำให้เปิดครั้งแรกช้า
- MongoDB Atlas Free มี quota และ performance จำกัด แต่พอสำหรับ demo
- APK ที่ไม่ผ่าน Play Store จะขึ้นเตือนตอนติดตั้ง
- ถ้า Gemini quota เต็ม แชทควร fallback เป็น rule-based response

## วิธีพูดบนเวที

ReJoy ใช้ cloud backend เป็นตัวหลักเพื่อให้มือถือใช้งานได้โดยไม่ต้องเปิดคอมผู้พัฒนาไว้ตลอดเวลา และยังมี Flutter web, วิดีโอ demo และ backend local เป็นชั้นสำรอง ทำให้การนำเสนอมีความเสี่ยงต่ำแม้อยู่ในสภาพแวดล้อมอินเทอร์เน็ตที่ไม่แน่นอน
