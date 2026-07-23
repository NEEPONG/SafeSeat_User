# 🚗 SafeSeat Mini — Client Mobile Application

> **Designated Driver & Safety On-Demand Service Platform**  
> แอปพลิเคชันให้บริการคนขับรถแทนผู้โดยสาร (Designated Driver Service) ชูจุดเด่นด้านความปลอดภัย ระบบเรียกรถและติดตามตำแหน่งแบบ Real-time พร้อมระบบรายงานและประเมินคนขับแบบครบวงจร

---

## 📌 Overview

**SafeSeat Mini** คือโมบายล์แอปพลิเคชันสำหรับผู้ใช้บริการที่ต้องการเรียกคนขับรถแทนเพื่อขับรถของผู้ใช้เองกลับบ้านอย่างปลอดภัย โดยเฉพาะยามค่ำคืนหรือหลังงานสังสรรค์ ระบบรองรับการค้นหาและแมตช์ทีมคนขับแบบคู่ (Leader & Follower Driver Team) การติดตามการเดินทางบนแผนที่แบบ Real-time ตลอดจนระบบความปลอดภัยและการรายงานเหตุการณ์ระดับมาตรฐานสูง

---

## ✨ Key Features

### 1. 🚘 Real-time Driver Requesting
- **Pickup & Drop-off Location Selection:** เลือกจุดรับ-ส่งบนแผนที่แบบโต้ตอบ พร้อมระบบคำนวณระยะทางและประเมินค่าบริการโดยอัตโนมัติ
- **Lady Mode (โหมดผู้หญิง):** ตัวเลือกพิเศษสำหรับผู้โดยสารหญิงที่ต้องการระบุทีมคนขับผู้หญิงเพื่อความปลอดภัยและความอุ่นใจ
- **Pub & Entertainment Venue Request:** ระบบรองรับการเรียกรถจากสถานบันเทิงหรือจุดให้บริการพันธมิตร

### 2. 🗺️ Interactive Live Tracking
- **Live Location Map:** แสดงตำแหน่งปัจจุบันและจุดหมายปลายทางด้วย `flutter_map`
- **Driver Status Sync:** ติดตามสถานะการเดินทางตั้งแต่คนขับกำลังเดินทางมารับ การรับผู้โดยสารขึ้นรถ จนถึงจุดหมายปลายทาง

### 3. ⭐️ Dual-Driver Review & Rating
- **Multi-Driver Feedback:** ระบบประเมินและให้คะแนนแยกระหว่าง **คนขับหลัก (Leader - D1)** และ **ผู้ติดตาม (Follower - D2)**
- **Trip History Logs:** บันทึกและเรียกดูประวัติการเดินทางโดยแบ่งหมวดหมู่ชัดเจน (กำลังดำเนินการ, สำเร็จ, ยกเลิกแล้ว)

### 4. 🛡️ Driver Incident Reporting & Status Tracking Timeline
- **Multi-Image Evidence Upload:** รองรับการแนบภาพถ่ายหลักฐานหลายรูปภาพขึ้น Supabase Storage พร้อมกัน
- **Visual Progress Timeline:** หน้าจอติดตามสถานะการรายงานปัญหาแบบเรียลไทม์ (Submitted $\rightarrow$ Reviewing $\rightarrow$ Resolved)
- **Accused Driver Information:** แสดงการ์ดข้อมูลและรูปโปรไฟล์คนขับผู้ถูกรายงานอย่างชัดเจน

### 5. 👤 Profile & Vehicle Management
- **User Profile Customization:** จัดการข้อมูลส่วนตัวและอัปโหลดภาพโปรไฟล์
- **User Car Management:** เพิ่มและบันทึกข้อมูลรถยนต์ส่วนบุคคลของผู้ใช้สำหรับเรียกบริการ

---

## 🏗️ Architecture & Technical Highlights

แอปพลิเคชัน SafeSeat Mini ถูกออกแบบด้วยสถาปัตยกรรม **Feature-First Clean Architecture** เพื่อแยกแยะความรับผิดชอบของโค้ดอย่างเป็นระบบ ง่ายต่อการบำรุงรักษาและการขยาย Feature ในอนาคต

```text
lib/
├── core/                   # Design Tokens, Theme, App Constants, Core Controllers
├── data/
│   ├── models/             # Data Models (RequestDriver, DriverReport, Review, Car, User)
│   └── repositories/       # Data Access & Backend HTTP API Communication
└── features/
    ├── auth/               # Authentication & User Session Management
    ├── home/               # Home Dashboard & Service Options
    ├── request_driver/     # Driver Request Flow, Live Map & Active Trip UI
    ├── history/            # Trip History, Dual-Driver Review & Incident Report System
    │   ├── controllers/    # Riverpod Notifiers (HistoryReportController, HistoryReviewController)
    │   └── screens/        # History, Report Form & Tracking Timeline Screens
    └── profile/            # User Profile & Vehicle Management
```

### 🔹 Layer Responsibilities
- **UI Screen Layer:** จัดการการแสดงผลและโต้ตอบกับผู้ใช้ โดยไม่มี Business Logic หรือการเชื่อมต่อ Database โดยตรง
- **Controller Layer (Riverpod):** ควบคุม State Management, Handle Business Logic, อัปโหลดสื่อบันทึก Supabase Storage และจัดการ Async Workflows
- **Repository Layer:** ทำหน้าที่เป็น Data Gateway สำหรับสื่อสารกับ Backend RESTful API และ Supabase Cloud Services

---

## 🛠️ Tech Stack & Key Packages

- **Core Framework:** [Flutter](https://flutter.dev/) (Dart SDK)
- **State Management:** [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) (`NotifierProvider`, `FutureProvider.family`)
- **Map & Geolocation:** [flutter_map](https://pub.dev/packages/flutter_map), [geolocator](https://pub.dev/packages/geolocator), [latlong2](https://pub.dev/packages/latlong2)
- **Cloud Storage & Backend:** [supabase_flutter](https://pub.dev/packages/supabase_flutter), RESTful API Integration (`http`)
- **UI & Media:** [google_fonts](https://pub.dev/packages/google_fonts), [image_picker](https://pub.dev/packages/image_picker)

---

## 🎨 UI/UX Design System

- **Color Palette:** Modern Slate & Deep Navy Blue (`#0D47A1`, `#0F172A`, `#F8FAFC`) ให้ความรู้สึกน่าเชื่อถือ สุขุม และปลอดภัย
- **Micro-Interactions:** การ์ดโปร่งแสง (Glassmorphism), Custom Visual Timelines, Smooth Dialog Transitions และ Interactive Image Zooming Viewers
