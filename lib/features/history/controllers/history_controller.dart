import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';
import 'package:safeseat_mini/data/models/driver_report_model.dart';
import 'package:safeseat_mini/data/models/review_model.dart';
import 'package:safeseat_mini/data/repositories/request_driver_repository.dart';

/// Riverpod provider to load trip history filtered by status type.
/// Usage: ref.watch(historyListProvider('active'))
final historyListProvider = FutureProvider.family<List<RequestDriverModel>, String>((ref, type) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];

  final repository = ref.read(requestDriverRepositoryProvider);
  return repository.getRequestsByUser(userId: user.phoneNo, type: type);
});

/// Riverpod provider to load driver reports submitted by the logged-in user.
final userReportsListProvider = FutureProvider<List<DriverReportModel>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];

  final repository = ref.read(requestDriverRepositoryProvider);
  return repository.getReportsByUser(user.phoneNo);
});

/// Riverpod provider for submitting driver reports.
final historyReportControllerProvider = NotifierProvider<HistoryReportController, bool>(() {
  return HistoryReportController();
});

class HistoryReportController extends Notifier<bool> {
  @override
  bool build() {
    return false; // represents isLoading state
  }

  /// Checks if a report has already been submitted for the trip.
  Future<Map<String, dynamic>> checkReportStatus(int requestId) async {
    final repo = ref.read(requestDriverRepositoryProvider);
    return repo.checkDriverReport(requestId);
  }

  /// Uploads report images and saves the driver report via repository.
  Future<bool> submitDriverReport({
    required int requestId,
    required String reportType,
    required String reportDetail,
    required int reportIndex,
    required List<File> images,
  }) async {
    state = true;
    try {
      String? reportImagePath;

      // 1. Upload report images to Supabase storage
      if (images.isNotEmpty) {
        final List<String> uploadedPaths = [];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        
        for (int i = 0; i < images.length; i++) {
          final file = images[i];
          final fileName = 'reports/driver/${requestId}_${i}_$timestamp.jpg';

          await Supabase.instance.client.storage
              .from('images')
              .upload(fileName, file);

          uploadedPaths.add(fileName);
        }
        
        reportImagePath = uploadedPaths.join(',');
      }

      // 2. Construct model
      final report = DriverReportModel(
        reportType: reportType,
        reportDetail: reportDetail,
        reportIndex: reportIndex,
        requestId: requestId,
        reportImagePath: reportImagePath,
      );

      // 3. Call repository to post to backend
      final repo = ref.read(requestDriverRepositoryProvider);
      final success = await repo.createDriverReport(report);
      
      state = false;
      return success;
    } catch (e) {
      state = false;
      rethrow;
    }
  }
}

/// Riverpod provider for submitting driver reviews.
final historyReviewControllerProvider = NotifierProvider<HistoryReviewController, bool>(() {
  return HistoryReviewController();
});

class HistoryReviewController extends Notifier<bool> {
  @override
  bool build() {
    return false; // represents isLoading state
  }

  /// Checks if a review has already been submitted for the trip.
  Future<Map<String, dynamic>> checkReviewStatus(int requestId) async {
    final repo = ref.read(requestDriverRepositoryProvider);
    return repo.checkReview(requestId);
  }

  /// Submits review ratings and comments for Leader and Follower drivers.
  Future<bool> submitTripReviews({
    required int requestId,
    required String? leaderUsername,
    required int leaderRating,
    required String? leaderComment,
    required String? followerUsername,
    required int followerRating,
    required String? followerComment,
  }) async {
    state = true;
    try {
      final repo = ref.read(requestDriverRepositoryProvider);

      // 1. Submit Leader (D1) Review
      if (leaderRating > 0 && leaderUsername != null) {
        final review = ReviewModel(
          requestId: requestId,
          driverUsername: leaderUsername,
          reviewRate: leaderRating,
          reviewComment: leaderComment?.trim().isNotEmpty == true ? leaderComment!.trim() : null,
        );
        await repo.createReview(review);
      }

      // 2. Submit Follower (D2) Review
      if (followerRating > 0 && followerUsername != null) {
        final review = ReviewModel(
          requestId: requestId,
          driverUsername: followerUsername,
          reviewRate: followerRating,
          reviewComment: followerComment?.trim().isNotEmpty == true ? followerComment!.trim() : null,
        );
        await repo.createReview(review);
      }

      state = false;
      return true;
    } catch (e) {
      state = false;
      rethrow;
    }
  }
}
