import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/data/models/user_model.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/data/models/car_model.dart';
import 'package:safeseat_mini/data/models/cartype_model.dart';
import 'package:safeseat_mini/data/repositories/profile_repository.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileController extends Notifier<bool> {
  @override
  bool build() {
    return false; // represents isLoading state
  }

  /// ดึงข้อมูลโปรไฟล์ผู้ใช้ล่าสุดจากเซิร์ฟเวอร์
  Future<UserModel?> getUserProfile(String phoneNo) async {
    state = true;
    try {
      final repository = ref.read(profileRepositoryProvider);
      final userModel = await repository.getUserProfile(phoneNo);

      // Update global user state
      ref.read(userProvider.notifier).setUser(userModel);
      state = false;
      return userModel;
    } catch (e) {
      // Handle error implicitly
    }
    state = false;
    return ref.read(userProvider);
  }

  /// ส่งข้อมูลอัปเดตโปรไฟล์ไปยังเซิร์ฟเวอร์
  Future<bool> editProfile(UserModel updatedUser) async {
    state = true;
    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.editProfile(updatedUser);

      ref.read(userProvider.notifier).setUser(updatedUser);
      state = false;
      return true;
    } catch (e) {
      state = false;
      return false;
    }
  }

  /// อัปโหลดรูปภาพ (ถ้ามี) และส่งข้อมูลอัปเดตโปรไฟล์ไปยังเซิร์ฟเวอร์
  Future<bool> editProfileWithImage({
    required UserModel currentUser,
    required String name,
    required String email,
    required int? gender,
    required String address,
    File? selectedImage,
  }) async {
    state = true;
    try {
      String? newImagePath = currentUser.profileImagePath;

      if (selectedImage != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'users/profile/${currentUser.phoneNo}_$timestamp.jpg';

        await Supabase.instance.client.storage
            .from('images')
            .upload(fileName, selectedImage);

        newImagePath = Supabase.instance.client.storage
            .from('images')
            .getPublicUrl(fileName);
      }

      final updatedUser = currentUser.copyWith(
        name: name,
        email: email,
        gender: gender,
        mainAddress: address,
        profileImagePath: newImagePath,
      );

      final repository = ref.read(profileRepositoryProvider);
      await repository.editProfile(updatedUser);

      ref.read(userProvider.notifier).setUser(updatedUser);
      state = false;
      return true;
    } catch (e) {
      state = false;
      return false;
    }
  }

  Future<bool> addUserCar(CarModel car) async {
    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.addUserCar(car);

      // Refresh cars
      ref.invalidate(userCarListProvider(car.userId));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUserCar(int carId, String phoneNo) async {
    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.deleteUserCar(carId, phoneNo);

      // Refresh cars
      ref.invalidate(userCarListProvider(phoneNo));
      return true;
    } catch (e) {
      return false;
    }
  }
}

final profileControllerProvider = NotifierProvider<ProfileController, bool>(() {
  return ProfileController();
});

final userCarListProvider = FutureProvider.family<List<CarModel>, String>((
  ref,
  phoneNo,
) async {
  final repository = ref.read(profileRepositoryProvider);
  return repository.fetchUserCars(phoneNo);
});

final carTypeProvider = FutureProvider<List<CarTypeModel>>((ref) async {
  final repository = ref.read(profileRepositoryProvider);
  return repository.fetchCarTypes();
});
