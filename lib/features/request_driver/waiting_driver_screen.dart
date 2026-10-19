import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:safeseat_mini/core/services/geocoding_service.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/features/request_driver/controllers/request_driver_controller.dart';
import 'package:safeseat_mini/features/request_driver/active_trip_screen.dart';
import 'package:safeseat_mini/features/profile/controllers/profile_controller.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';

class WaitingDriverScreen extends ConsumerStatefulWidget {
  final int requestId;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng? pickupLatLng;
  final LatLng? dropoffLatLng;
  final String carDetails;
  final double price;

  const WaitingDriverScreen({
    super.key,
    required this.requestId,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.pickupLatLng,
    this.dropoffLatLng,
    required this.carDetails,
    required this.price,
  });

  @override
  ConsumerState<WaitingDriverScreen> createState() =>
      _WaitingDriverScreenState();
}

class _WaitingDriverScreenState extends ConsumerState<WaitingDriverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _statusTimer;
  bool _isCancelling = false;
  String _statusMessage = 'กำลังค้นหาทีมคนขับ...';
  RequestDriverModel? _acceptedRequest;
  late String _pickupAddress;
  late String _dropoffAddress;

  bool _needsPlaceLookup(String value) =>
      value == 'กำลังค้นหาสถานที่...' || value == 'ไม่พบชื่อสถานที่';

  Future<void> _resolvePlace(LatLng point, {required bool pickup}) async {
    final name = await GeocodingService.reverseGeocodeLatLng(point);
    if (!mounted) return;
    setState(() {
      if (pickup) {
        _pickupAddress = name ?? 'ไม่พบชื่อสถานที่';
      } else {
        _dropoffAddress = name ?? 'ไม่พบชื่อสถานที่';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _pickupAddress = widget.pickupAddress;
    _dropoffAddress = widget.dropoffAddress;
    if (widget.pickupLatLng != null && _needsPlaceLookup(_pickupAddress)) {
      _resolvePlace(widget.pickupLatLng!, pickup: true);
    }
    if (widget.dropoffLatLng != null && _needsPlaceLookup(_dropoffAddress)) {
      _resolvePlace(widget.dropoffLatLng!, pickup: false);
    }
    // Setup matching animation (concentric radar rings pulsing)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start polling status every 3 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkRequestStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkRequestStatus() async {
    if (!mounted) return;
    try {
      final request = await ref
          .read(requestDriverControllerProvider.notifier)
          .checkRequestStatus(widget.requestId);

      if (!mounted) return;

      if (request != null) {
        final status = request.requestStatus;
        if (status != 'กำลังค้นหาคนขับ') {
          _statusTimer?.cancel();
          if (mounted) {
            setState(() {
              _statusMessage = 'ทีมคนขับรับงานแล้ว';
              _acceptedRequest = request;
            });
            _showSuccessDialog();
          }
        }
      }
    } catch (e) {
      debugPrint('Error polling request status: $e');
    }
  }

  Future<void> _cancelRequest() async {
    if (_isCancelling) return;

    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'ยกเลิกการเรียกรถ',
      message: 'คุณแน่ใจหรือไม่ว่าต้องการยกเลิกคำขอเรียกรถนี้?',
      confirmText: 'ยกเลิกการเรียก',
      cancelText: 'รอคนขับต่อ',
      isDestructive: true,
      icon: Icons.cancel_outlined,
      iconColor: const Color(0xFFEF4444),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      final success = await ref
          .read(requestDriverControllerProvider.notifier)
          .cancelRequest(widget.requestId);

      if (!mounted) return;

      if (success) {
        _statusTimer?.cancel();
        // Refresh wallet balance to reflect refund
        final user = ref.read(userProvider);
        if (user != null) {
          ref
              .read(profileControllerProvider.notifier)
              .getUserProfile(user.phoneNo);
        }
        AppSnackBar.showSuccess(context, 'ยกเลิกรายการเรียกรถเรียบร้อยแล้ว');
        Navigator.of(context).pop(); // Go back to details
      } else {
        throw Exception('Failed to cancel request on server');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'เกิดข้อผิดพลาดในการยกเลิก: $e');
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    final leader = _acceptedRequest?.leader;
    final follower = _acceptedRequest?.follower;
    final leaderName = leader != null
        ? '${leader.firstname} ${leader.lastname}'
        : 'คนขับของ SafeSeat';
    final followerVehicle =
        follower?.vehicleSummary ??
        (leader?.licensePlate != null
            ? 'ทะเบียน ${leader!.licensePlate}'
            : 'ไม่ระบุ');

    AppDialog.showSuccess(
      context: context,
      title: 'พบทีมคนขับแล้ว',
      message: 'ทีมคนขับรับงานแล้วและกำลังมารับคุณ',
      buttonText: 'ดูสถานะการเดินทาง',
      customContent: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'คนขับหลัก: $leaderName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.directions_car_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'รถขับตาม: $followerVehicle',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      onDismiss: () {
        final reqState = ref.read(requestDriverControllerProvider);
        final request = _acceptedRequest;
        final pickupLatLng = request != null
            ? LatLng(request.pickupLatitude, request.pickupLongitude)
            : (reqState.pickupLatLng ?? const LatLng(18.8972, 99.0112));
        final dropoffLatLng = request != null
            ? LatLng(request.dropoffLatitude, request.dropoffLongitude)
            : (reqState.dropoffLatLng ?? const LatLng(18.8972, 99.0112));

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ActiveTripScreen(
              requestId: widget.requestId,
              pickupAddress: _pickupAddress,
              dropoffAddress: _dropoffAddress,
              pickupLatLng: pickupLatLng,
              dropoffLatLng: dropoffLatLng,
              carDetails: widget.carDetails,
              price: widget.price,
              initialRequestData: _acceptedRequest,
            ),
          ),
          (route) => route.isFirst,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = AppTheme.primaryColor;

    return PopScope(
      canPop:
          false, // Prevent physical back button, user must explicitly cancel
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 20),
                      // Premium matching header
                      const Text(
                        'กำลังจับคู่คนขับรถ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Pulsing Radar Search Animation
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return SizedBox(
                            width: 200,
                            height: 200,
                            child: CustomPaint(
                              painter: RadarPainter(
                                _animationController.value,
                                themeColor,
                              ),
                              child: Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: themeColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: themeColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_searching,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Ride details summary card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Pickup Location
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.pickupColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _pickupAddress,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Dropoff Location
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.dropoffColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _dropoffAddress,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            // Vehicle and fare
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.carDetails,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '฿${widget.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Cancel button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isCancelling ? null : _cancelRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: AppTheme.errorColor,
                            disabledBackgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: _isCancelling
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.errorColor,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'ยกเลิกการเรียก',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double animationValue;
  final Color themeColor;

  RadarPainter(this.animationValue, this.themeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final value = (animationValue + i / 3.0) % 1.0;
      final radius = maxRadius * value;
      final opacity = 1.0 - value;

      final paint = Paint()
        ..color = themeColor.withValues(alpha: opacity * 0.15)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);

      final strokePaint = Paint()
        ..color = themeColor.withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
