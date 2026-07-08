import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controller สำหรับหน้า Home
/// ปัจจุบันยังไม่มี business logic เพิ่มเติม
/// สร้างไว้เพื่อให้สอดคล้องกับ Pattern ของ Features อื่นๆ
/// และรองรับการขยายฟีเจอร์ในอนาคต (เช่น โปรโมชั่น, การแจ้งเตือน)
class HomeController extends Notifier<bool> {
  @override
  bool build() {
    return false; // represents isLoading state
  }
}

final homeControllerProvider = NotifierProvider<HomeController, bool>(() {
  return HomeController();
});
