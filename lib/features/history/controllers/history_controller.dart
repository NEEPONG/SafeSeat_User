import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';
import 'package:safeseat_mini/data/repositories/request_driver_repository.dart';

/// Riverpod provider to load trip history filtered by status type.
/// Usage: ref.watch(historyListProvider('active'))
final historyListProvider = FutureProvider.family<List<RequestDriverModel>, String>((ref, type) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];

  final repository = ref.read(requestDriverRepositoryProvider);
  return repository.getRequestsByUser(userId: user.phoneNo, type: type);
});
