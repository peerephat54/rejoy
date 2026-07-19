# Unity 2D Side Scrolling Player

สคริปต์นี้อยู่ที่ `Assets/Scripts/Player2DSideScroller.cs`

## วิธีใช้

1. สร้าง GameObject ผู้เล่นใน Unity
2. ใส่ `Rigidbody2D` และ Collider2D
3. ลากสคริปต์ `Player2DSideScroller` ไปใส่ที่ Player
4. สร้าง child object สำหรับเช็กพื้น เช่น `GroundCheck`
5. ลาก child object นั้นไปใส่ในช่อง `Ground Check Point`
6. ตั้งค่า `Ground Layer` ให้เป็น layer ของพื้น

## ความสามารถ

- เดินซ้ายขวา
- กระโดด
- Coyote time
- Jump buffer
- ปรับแรงตกและ short hop
- Dash แบบเปิด/ปิดได้

## ปุ่มควบคุมเริ่มต้น

- เดิน: `A/D` หรือ ลูกศรซ้าย/ขวา
- กระโดด: `Space`
- Dash: `Left Shift`
