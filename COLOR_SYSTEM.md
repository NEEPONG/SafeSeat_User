# 🎨 SafeSeat Color System & Design Tokens Guide

เอกสารคู่มือชุดสีและระบบการออกแบบ (Design Tokens & Color Palette) สำหรับโปรเจกต์ **SafeSeat** เพื่อใช้เป็นมาตรฐานกลางในการออกแบบ UI/UX และการพัฒนาส่วนติดต่อผู้ใช้ (User Interface) ให้มีความเป็นเอกภาพ สวยงาม และถูกต้องตามหลักการเข้าถึง (Accessibility)

---

## 📌 1. Brand & Core Colors (สีหลักของแบรนด์)

ชุดสีอัตลักษณ์ของแบรนด์ SafeSeat ที่สะท้อนถึงความปลอดภัย ความน่าเชื่อถือ และความทันสมัย

| ชื่อสี (Color Token) | ตัวอย่าง | HEX Code | RGB | Flutter Code | การนำไปใช้งาน |
|---|:---:|---|---|---|---|
| **Primary Brand** | 🟦 | `#2340A7` | `rgb(35, 64, 167)` | `const Color(0xFF2340A7)` | สีหลักของแอป, ปุ่มกดหลัก (Primary Button), App Bar, Header |
| **Accent / Electric Blue** | 🔹 | `#2563EB` | `rgb(37, 99, 235)` | `const Color(0xFF2563EB)` | ลิงก์, ปุ่มไฮไลต์ย่อย, Active State |
| **Deep Brand Blue** | 🔷 | `#0044C9` | `rgb(0, 68, 201)` | `const Color(0xFF0044C9)` | หัวข้อย่อยสำคัญ, ไอคอนแบรนด์ |

---

## 🚦 2. Semantic & Feedback Colors (ระบบสีแจ้งเตือนและสถานะ)

ระบบสีที่สื่อความหมายโดยตรง (Semantic Colors) เพื่อให้ผู้ใช้งานเข้าใจผลลัพธ์ของการกระทำได้ทันที

| หมวดหมู่ (Semantic) | ตัวอย่าง | HEX Code | RGB | Flutter Code | บริบทการใช้งาน |
|---|:---:|---|---|---|---|
| **Success (สำเร็จ)** | 🟢 | `#059669` | `rgb(5, 150, 105)` | `const Color(0xFF059669)` | ทำรายการสำเร็จ, เข้าสู่ระบบสำเร็จ, ส่งรีวิวสำเร็จ, เติมเงินสำเร็จ |
| **Error / Destructive (ข้อผิดพลาด)** | 🔴 | `#DC2626` | `rgb(220, 38, 38)` | `const Color(0xFFDC2626)` | ทำรายการไม่สำเร็จ, รหัสผ่านไม่ถูกต้อง, ปุ่มลบ, ปุ่มยกเลิกคำขอ |
| **Warning (คำเตือน)** | 🟠 | `#D97706` | `rgb(217, 119, 6)` | `const Color(0xFFD97706)` | เตือนกรอกข้อมูล, ยอดเงินไม่เพียงพอ, แจ้งสิทธิ์เข้าถึงพิกัด |
| **Info (ข้อมูลทั่วไป)** | ⬛ | `#0F172A` | `rgb(15, 23, 42)` | `const Color(0xFF0F172A)` | การคัดลอกเบอร์/ลิงก์, ข้อมูลข่าวสารทั่วไป |

---

## 🚗 3. Trip Status Flow Colors (สีแสดงสถานะการเดินทาง 5 ขั้นตอน)

การแสดงสถานะการเดินทางแบบเรียลไทม์ (Live Trip Tracking) ตามขั้นตอนการปฏิบัติงานของคู่หูคนขับ

| ลำดับขั้นตอน | สถานะภาษาไทย | สีข้อความ & ไอคอน (Foreground) | สีพื้นหลังการ์ด (Badge Background) |
|:---:|---|---|---|
| **Step 1** | **กำลังค้นหาคนขับ** | `#94A3B8` &nbsp; `Color(0xFF94A3B8)` | `#F1F5F9` &nbsp; `Color(0xFFF1F5F9)` |
| **Step 2** | **คนขับกำลังมารับ** | `#2563EB` &nbsp; `Color(0xFF2563EB)` | `#DBEAFE` &nbsp; `Color(0xFFDBEAFE)` |
| **Step 3** | **ถึงจุดนัดหมายแล้ว** | `#D97706` &nbsp; `Color(0xFFD97706)` | `#FEF3C7` &nbsp; `Color(0xFFFEF3C7)` |
| **Step 4** | **กำลังนำทางไปปลายทาง** | `#7C3AED` &nbsp; `Color(0xFF7C3AED)` | `#F3E8FF` &nbsp; `Color(0xFFF3E8FF)` |
| **Step 5** | **การเดินทางเสร็จสิ้น** | `#059669` &nbsp; `Color(0xFF059669)` | `#D1FAE5` &nbsp; `Color(0xFFD1FAE5)` |

---

## 📍 4. Map & Navigation Markers (พิกัดและเส้นทางบนแผนที่)

| องค์ประกอบแผนที่ | สี | HEX Code | Flutter Code | ความหมาย |
|---|:---:|---|---|---|
| **Pickup Marker (จุดรับ)** | 🔴 | `#EF4444` | `const Color(0xFFEF4444)` | พิกัดที่คนขับจะไปรับผู้ใช้และรถยนต์ |
| **Dropoff Marker (จุดส่ง)** | 🟢 | `#10B981` | `const Color(0xFF10B981)` | จุดหมายปลายทางที่ผู้ใช้ต้องการให้ขับไปส่ง |
| **Driver Marker (ตำแหน่งคนขับ)** | 🔵 | `#2340A7` | `const Color(0xFF2340A7)` | พิกัดสดของรถคู่หูคนขับ (Live GPS) |
| **Polyline (เส้นทางเดินรถ)** | 🟦 | `#2340A7` | `const Color(0xFF2340A7)` | เส้นทางแนะนำจากจุดรับไปยังจุดส่ง |

---

## ⚪ 5. Neutral & Surface Colors (พื้นผิวและข้อความ)

ชุดสีโทนกลาง (Grayscale & Slate) สำหรับโครงสร้าง Layout, การ์ด และระดับความสำคัญของตัวอักษร

| องค์ประกอบ UI | ตัวอย่าง | HEX Code | Flutter Code | รายละเอียด |
|---|:---:|---|---|---|
| **App Background** | ⬜ | `#F8FAFC` | `const Color(0xFFF8FAFC)` | พื้นหลังหลักของทุกหน้าจอ (Slate 50) |
| **Card / Modal Surface** | ⬜ | `#FFFFFF` | `Colors.white` | พื้นหลังการ์ด, ป๊อปอัป Dialog, Bottom Sheet |
| **Input Background** | ◽ | `#F3F4F6` | `const Color(0xFFF3F4F6)` | พื้นหลังช่องกรอกข้อความ (Form Input) |
| **Border / Divider** | ◽ | `#E2E8F0` | `const Color(0xFFE2E8F0)` | เส้นขอบการ์ดและเส้นแบ่งส่วนเนื้อหา |
| **Text Primary (หัวข้อ)** | ⬛ | `#1E293B` | `const Color(0xFF1E293B)` | ข้อความหัวข้อหลัก, ข้อความเน้นความสำคัญ (Slate 800) |
| **Text Secondary (คำอธิบาย)** | ◼️ | `#64748B` | `const Color(0xFF64748B)` | ข้อความคำอธิบายย่อย, วันที่, ป้ายกำกับ (Slate 500) |
| **Text Muted / Placeholder** | ◽ | `#94A3B8` | `const Color(0xFF94A3B8)` | ข้อความตัวอย่าง (Hint text), ไอคอนที่ปิดใช้งาน (Slate 400) |

---

## 💻 6. ตัวอย่างการเรียกใช้งานใน Flutter Code

### 6.1 เรียกใช้ผ่าน `AppTheme`
```dart
import 'package:safeseat_mini/core/theme/app_theme.dart';

// ตัวอย่างการใช้สีแบรนด์
Container(
  color: AppTheme.primaryColor,
  child: const Text('SafeSeat'),
);
```

### 6.2 เรียกใช้ผ่าน `AppFeedback`
```dart
import 'package:safeseat_mini/core/utils/app_feedback.dart';

// แสดง Toast สำเร็จ
AppSnackBar.showSuccess(context, 'บันทึกข้อมูลสำเร็จ');

// แสดง Toast ข้อผิดพลาด
AppSnackBar.showError(context, 'เกิดข้อผิดพลาดในการเชื่อมต่อ');

// แสดง Dialog ยืนยัน
final confirmed = await AppDialog.showConfirm(
  context: context,
  title: 'ยืนยันการลบ',
  message: 'คุณแน่ใจหรือไม่ว่าต้องการลบรายการนี้?',
  isDestructive: true,
);
```
