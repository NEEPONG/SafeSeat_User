import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/data/repositories/auth_repository.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';

import 'package:safeseat_mini/data/models/car_model.dart';

class AuthController extends Notifier<bool> {
  @override
  bool build() {
    return false; // state represents 'isLoading'
  }

  Future<String?> login(String phone, String password) async {
    if (phone.isEmpty || password.isEmpty) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }

    state = true;
    try {
      final repository = ref.read(authRepositoryProvider);
      final userModel = await repository.login(phone, password);
      
      ref.read(userProvider.notifier).setUser(userModel);
      state = false;
      return null; // Null means success
    } catch (error) {
      state = false;
      return 'ไม่พบข้อมูลผู้ใช้';
    }
  }

  Future<String?> register({
    required String phone,
    required String name,
    required int gender,
    required String email,
    required String password,
    CarModel? car,
  }) async {
    state = true;
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.register(
        phone: phone,
        name: name,
        gender: gender,
        email: email,
        password: password,
        car: car,
      );
      
      state = false;
      return null; // Null means success
    } catch (error) {
      state = false;
      final err = error.toString().replaceAll('Exception: ', '');
      if (err.contains('ซ') || err.contains('เบอร์โทรศัพท์นี้ถูกใช้งานแล้ว') || err.contains('already')) {
        return 'ข้อมูลผู้ใช้ซํ้า กรุณาลองใหม่อีกครั้ง';
      }
      return err;
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, bool>(() {
  return AuthController();
});
