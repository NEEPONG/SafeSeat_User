import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:safeseat_mini/core/constants/api_constants.dart';
import 'package:safeseat_mini/data/models/user_model.dart';
import 'package:safeseat_mini/data/models/car_model.dart';
import 'package:safeseat_mini/data/models/cartype_model.dart';

class ProfileRepository {
  Future<UserModel> getUserProfile(String phoneNo) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/profile/$phoneNo');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return UserModel.fromJson(responseData['user']);
    } else {
      throw Exception('ไม่สามารถดึงข้อมูลโปรไฟล์ได้');
    }
  }

  Future<void> editProfile(UserModel updatedUser) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/profile/update');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updatedUser.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('อัปเดตข้อมูลโปรไฟล์ไม่สำเร็จ');
    }
  }

  Future<UserModel> topUpWallet(String phoneNo, double amount) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/profile/topup');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phoneNo': phoneNo,
        'amount': amount,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson(data['user']);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'เกิดข้อผิดพลาดในการเติมเงิน');
    }
  }

  Future<void> addUserCar(CarModel car) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/profile/car');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(car.toJson()),
    );
    if (response.statusCode != 201) {
      throw Exception('เพิ่มรถไม่สำเร็จ');
    }
  }

  Future<void> deleteUserCar(int carId, String phoneNo) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/profile/car/$carId');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception('ลบรถไม่สำเร็จ');
    }
  }

  Future<List<CarModel>> fetchUserCars(String phoneNo) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/profile/car/$phoneNo');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List carsJson = data['cars'];
      return carsJson.map((json) => CarModel.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<CarTypeModel>> fetchCarTypes() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/profile/cartype/all');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List typesJson = data['carTypes'];
      return typesJson.map((json) => CarTypeModel.fromJson(json)).toList();
    }
    return [];
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});
