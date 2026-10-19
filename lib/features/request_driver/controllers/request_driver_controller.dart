import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';
import 'package:safeseat_mini/data/repositories/request_driver_repository.dart';

class RequestDriverState {
  final String? pickupAddress;
  final LatLng? pickupLatLng;
  final String? dropoffAddress;
  final LatLng? dropoffLatLng;
  final bool isLoading;

  RequestDriverState({
    this.pickupAddress,
    this.pickupLatLng,
    this.dropoffAddress,
    this.dropoffLatLng,
    this.isLoading = false,
  });

  RequestDriverState copyWith({
    String? pickupAddress,
    LatLng? pickupLatLng,
    String? dropoffAddress,
    LatLng? dropoffLatLng,
    bool? isLoading,
  }) {
    return RequestDriverState(
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLatLng: pickupLatLng ?? this.pickupLatLng,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLatLng: dropoffLatLng ?? this.dropoffLatLng,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RequestDriverController extends Notifier<RequestDriverState> {
  @override
  RequestDriverState build() {
    return RequestDriverState();
  }

  void setPickup(String address, LatLng latLng) {
    state = state.copyWith(pickupAddress: address, pickupLatLng: latLng);
  }

  void setDropoff(String address, LatLng latLng) {
    state = state.copyWith(dropoffAddress: address, dropoffLatLng: latLng);
  }

  void clearRequest() {
    state = RequestDriverState();
  }

  /// Sends the designated driver request to the backend
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
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(requestDriverRepositoryProvider);
      final requestId = await repository.createRequest(
        dropoffLatitude: dropoffLatitude,
        dropoffLongitude: dropoffLongitude,
        isLadyMode: isLadyMode,
        note: note,
        paymentMethod: paymentMethod,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        reqDistance: reqDistance,
        requestFee: requestFee,
        userId: userId,
        userCarId: userCarId,
      );
      state = state.copyWith(isLoading: false);
      return requestId;
    } catch (e) {
      debugPrint('Error creating request: $e');
    }
    state = state.copyWith(isLoading: false);
    return null;
  }

  /// Polls the backend to check the request status and assigned driver info
  Future<RequestDriverModel?> checkRequestStatus(int requestId) async {
    try {
      final repository = ref.read(requestDriverRepositoryProvider);
      return await repository.checkRequestStatus(requestId);
    } catch (e) {
      debugPrint('Error checking request status: $e');
    }
    return null;
  }

  /// Deletes the request from the backend
  Future<bool> cancelRequest(int requestId) async {
    try {
      final repository = ref.read(requestDriverRepositoryProvider);
      return await repository.cancelRequest(requestId);
    } catch (e) {
      debugPrint('Error canceling request: $e');
    }
    return false;
  }
}

final requestDriverControllerProvider =
    NotifierProvider<RequestDriverController, RequestDriverState>(() {
      return RequestDriverController();
    });
