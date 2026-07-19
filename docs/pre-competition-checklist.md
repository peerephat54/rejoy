# ReJoy Pre-Competition Checklist

ใช้ไฟล์นี้เช็กก่อนเดโม TICTA/NSC เพื่อให้มีแผนหลักและแผนสำรองครบ

## ลำดับระบบสำรอง

1. Cloud backend บน Render Free + MongoDB Atlas Free
2. APK demo ติดตั้งในมือถือ
3. Flutter web/Chrome เป็นตัวสำรอง
4. วิดีโอ demo 1-2 นาทีเป็น backup
5. Backend local ในโน้ตบุ๊กเป็น backup ชั้นสุดท้าย

## ก่อนขึ้นเวที 30 นาที

- เปิด URL backend cloud 1 ครั้งเพื่อปลุก Render Free
- เช็ก `/api/health` ต้องตอบกลับได้
- ลอง login/register ในมือถือ
- ลองเปิดหน้า Island, Missions, Profile, SOS
- ลอง Export PDF หรือปุ่มพิมพ์ให้หมอ
- เปิดวิดีโอ demo backup เตรียมไว้
- เปิด backend local ในโน้ตบุ๊กไว้ เผื่ออินเทอร์เน็ต/Render มีปัญหา

## เช็ก API cloud

ตั้งค่า URL backend ก่อน เช่น:

```powershell
$env:REJOY_API_BASE_URL="https://YOUR-REJOY-BACKEND.onrender.com"
powershell -ExecutionPolicy Bypass -File "C:\Users\User\Documents\New project\scripts\check-rejoy-api.ps1"
```

ถ้าต้องการทดสอบ login/report จริง:

```powershell
$env:REJOY_API_BASE_URL="https://YOUR-REJOY-BACKEND.onrender.com"
powershell -ExecutionPolicy Bypass -File "C:\Users\User\Documents\New project\scripts\check-rejoy-api.ps1" -FullSmoke
```

ผลที่ควรเห็น:

- Health เป็น OK
- Database เป็น connected
- Quest seed ready เป็น True
- Active quests อย่างน้อย 10

## Build APK สำหรับมือถือด้วย cloud backend

หลังจากได้ URL Render จริงแล้ว ให้รัน:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\User\Documents\New project\scripts\build-rejoy-mobile-demo.ps1" -ApiBaseUrl "https://YOUR-REJOY-BACKEND.onrender.com"
```

ไฟล์ APK จะอยู่ที่:

```text
C:\Users\User\Documents\New project\rejoy\build\app\outputs\flutter-apk\app-release.apk
```

## Build Flutter web backup

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\User\Documents\New project\scripts\build-rejoy-web-demo.ps1" -ApiBaseUrl "https://YOUR-REJOY-BACKEND.onrender.com"
```

ไฟล์เว็บจะอยู่ที่:

```text
C:\Users\User\Documents\New project\rejoy\build\web
```

## สร้างแพ็ก demo ทั้ง APK + web

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\User\Documents\New project\scripts\prepare-rejoy-demo-package.ps1" -ApiBaseUrl "https://YOUR-REJOY-BACKEND.onrender.com"
```

ผลลัพธ์จะอยู่ที่:

```text
C:\Users\User\Documents\New project\demo-package
```

## Backend local backup

ถ้า cloud ล่ม ให้เปิด backend local:

```powershell
cd "C:\Users\User\Documents\New project\backend"
& "C:\Program Files\nodejs\npm.cmd" run dev
```

จากนั้นเปิด Flutter Chrome:

```powershell
cd "C:\Users\User\Documents\New project\rejoy"
flutter run -d chrome
```

ถ้า port 3000 ชน:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\User\Documents\New project\scripts\stop-rejoy-backend-port.ps1"
```

## VS Code Tasks

ใน VS Code กด:

```text
Terminal > Run Task...
```

แล้วเลือก:

- ReJoy: Backend Dev
- ReJoy: Flutter Chrome
- ReJoy: Check API
- ReJoy: Check API Full Smoke
- ReJoy: Stop Backend Port 3000
- ReJoy: Build Mobile Demo APK
- ReJoy: Build Web Demo
- ReJoy: Prepare Demo Package
- ReJoy: Start Full Demo
