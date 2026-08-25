import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:safeseat_mini/core/constants/api_constants.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';
import 'package:safeseat_mini/data/models/review_model.dart';
import 'package:safeseat_mini/data/models/driver_report_model.dart';

class RequestDriverRepository {
  Future<int?> createRequest({
    required double dropoffLatitude,
    required double dropoffLongitude,
    required bool isLadyMode,
    required String note,
    required String paymentMethod,
    required double pickupLatitude,
    required double pickupLongitude,
    required double reqDistance,
    required double requestFee,
    required String userId,
    required int userCarId,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/request');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'dropofflatitude': dropoffLatitude,
        'dropofflongitude': dropoffLongitude,
        'isladymode': isLadyMode,
        'note': note,
        'paymentmethod': paymentMethod,
        'pickuplatitude': pickupLatitude,
        'pickuplongitude': pickupLongitude,
        'reqdistance': reqDistance,
        'requestfee': requestFee,
        'user_id': userId,
        'user_car_id': userCarId,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final request = data['request'];
      return request != null ? request['requestid'] as int? : null;
    }

    String errorMsg = 'ไม่สามารถสร้างคำขอได้ กรุณาลองใหม่อีกครั้ง';
    try {
      final data = jsonDecode(response.body);
      if (data['message'] != null) {
        errorMsg = data['message'].toString();
      } else if (data['error'] != null) {
        errorMsg = data['error'].toString();
      }
    } catch (_) {}
    throw Exception(errorMsg);
  }

  Future<RequestDriverModel?> checkRequestStatus(int requestId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/request/$requestId');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final requestJson = data['request'] as Map<String, dynamic>?;
      if (requestJson != null) {
        return RequestDriverModel.fromJson(requestJson);
      }
    }
    return null;
  }

  Future<bool> cancelRequest(int requestId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/request/$requestId');
    final response = await http.delete(url, headers: {'Content-Type': 'application/json'});

    return response.statusCode == 200;
  }

  Future<List<RequestDriverModel>> getRequestsByUser({
    required String userId,
    required String type,
    int? page,
    int? limit,
  }) async {
    String queryParams = 'type=$type';
    if (page != null) queryParams += '&page=$page';
    if (limit != null) queryParams += '&limit=$limit';

    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/request/user/$userId?$queryParams');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['requests'] ?? [];
      return list.map((json) => RequestDriverModel.fromJson(json)).toList();
    }
    return [];
  }

  Future<bool> createReview(ReviewModel review) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/review');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(review.toJson()),
    );

    if (response.statusCode != 201) {
      String message = 'Failed to submit review';
      try {
        final data = jsonDecode(response.body);
        if (data['error'] != null) message = data['error'].toString();
      } catch (_) {}
      throw Exception(message);
    }
    return true;
  }

  Future<Map<String, dynamic>> checkReview(int requestId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/user/review/check/$requestId');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['reviews'] ?? [];
      final reviews = list.map((json) => ReviewModel.fromJson(json)).toList();
      return {
        'hasReviewed': data['hasReviewed'] ?? false,
        'reviews': reviews,
      };
    }
    return {
      'hasReviewed': false,
      'reviews': <ReviewModel>[],
    };
  }

  Future<bool> createDriverReport(DriverReportModel report) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/driver-reports');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(report.toJson()),
    );

    if (response.statusCode != 201) {
      String message = 'Failed to submit driver report';
      try {
        final data = jsonDecode(response.body);
        if (data['error'] != null) message = data['error'].toString();
      } catch (_) {}
      throw Exception(message);
    }

    return true;
  }

  Future<Map<String, dynamic>> checkDriverReport(int requestId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/driver-reports/check/$requestId');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      DriverReportModel? report;
      if (data['report'] != null) {
        report = DriverReportModel.fromJson(data['report']);
      }
      return {
        'hasReported': data['hasReported'] ?? false,
        'report': report,
      };
    }
    return {
      'hasReported': false,
      'report': null,
    };
  }

  Future<List<DriverReportModel>> getReportsByUser(String userId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/driver-reports?userId=$userId');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => DriverReportModel.fromJson(json)).toList();
    }
    return [];
  }
}

final requestDriverRepositoryProvider = Provider<RequestDriverRepository>((ref) {
  return RequestDriverRepository();
});
