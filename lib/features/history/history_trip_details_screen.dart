import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:safeseat_mini/core/services/geocoding_service.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/widgets/driver_avatar.dart';
import 'package:safeseat_mini/data/models/driver_report_model.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';
import 'package:safeseat_mini/data/models/review_model.dart';
import 'package:safeseat_mini/features/history/controllers/history_controller.dart';
import 'package:safeseat_mini/features/history/history_trip_review_screen.dart';
import 'package:safeseat_mini/features/history/history_trip_report_screen.dart';
import 'package:safeseat_mini/features/history/history_report_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryTripDetailsScreen extends ConsumerStatefulWidget {
  final RequestDriverModel trip;

  const HistoryTripDetailsScreen({super.key, required this.trip});

  @override
  ConsumerState<HistoryTripDetailsScreen> createState() =>
      _HistoryTripDetailsScreenState();
}

class _HistoryTripDetailsScreenState
    extends ConsumerState<HistoryTripDetailsScreen> {
  bool _hasReviewed = false;
  List<ReviewModel> _existingReviews = [];
  bool _hasReported = false;
  DriverReportModel? _existingReport;

  String? _pickupAddress;
  String? _dropoffAddress;
  bool _isLoadingPickupAddress = true;
  bool _isLoadingDropoffAddress = true;

  @override
  void initState() {
    super.initState();
    _checkReviewStatus();
    _checkReportStatus();
    _loadLocationNames();
  }

  void _loadLocationNames() {
    final trip = widget.trip;
    _resolveAddress(trip.pickupLatitude, trip.pickupLongitude, isPickup: true);
    _resolveAddress(
      trip.dropoffLatitude,
      trip.dropoffLongitude,
      isPickup: false,
    );
  }

  Future<void> _resolveAddress(
    double latitude,
    double longitude, {
    required bool isPickup,
  }) async {
    String? name;
    try {
      name = await GeocodingService.reverseGeocode(latitude, longitude);
    } catch (_) {
      // Keep the place-name fallback when the lookup cannot complete.
    }
    if (!mounted) return;
    setState(() {
      if (isPickup) {
        _pickupAddress = name;
        _isLoadingPickupAddress = false;
      } else {
        _dropoffAddress = name;
        _isLoadingDropoffAddress = false;
      }
    });
  }

  Future<void> _checkReviewStatus() async {
    try {
      final checkResult = await ref
          .read(historyReviewControllerProvider.notifier)
          .checkReviewStatus(widget.trip.requestId);
      if (mounted) {
        setState(() {
          _hasReviewed = checkResult['hasReviewed'] ?? false;
          _existingReviews = List<ReviewModel>.from(
            checkResult['reviews'] ?? [],
          );
        });
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _checkReportStatus() async {
    try {
      final checkResult = await ref
          .read(historyReportControllerProvider.notifier)
          .checkReportStatus(widget.trip.requestId);
      if (mounted) {
        setState(() {
          _hasReported = checkResult['hasReported'] ?? false;
          _existingReport = checkResult['report'] as DriverReportModel?;
        });
      }
    } catch (e) {
      // Ignored
    }
  }

  String _formatDateTime(String dateTimeStr) {
    var parsed = DateTime.tryParse(dateTimeStr);
    if (parsed == null) return dateTimeStr;
    parsed = parsed.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Safety check for month range
    final monthIdx = parsed.month - 1;
    final month = (monthIdx >= 0 && monthIdx < 12) ? months[monthIdx] : 'Oct';

    final day = parsed.day.toString().padLeft(2, '0');
    final year = parsed.year;

    // Formatting AM/PM format
    int hourInt = parsed.hour;
    final period = hourInt >= 12 ? 'PM' : 'AM';
    if (hourInt > 12) hourInt -= 12;
    if (hourInt == 0) hourInt = 12;
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');

    return '$month $day, $year • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final pickupLatLng = LatLng(trip.pickupLatitude, trip.pickupLongitude);
    final dropoffLatLng = LatLng(trip.dropoffLatitude, trip.dropoffLongitude);

    final orderCode = '#ORD${trip.requestId.toString().padLeft(4, '0')}';
    final dateStr = _formatDateTime(trip.reqDateTime);

    // Leader info check
    final leaderName = trip.leader != null
        ? '${trip.leader!.firstname} ${trip.leader!.lastname}'
        : '';
    final leaderSubtitle = trip.leader != null ? 'คนขับหลัก • ขับรถให้คุณ' : '';

    // Follower info check
    final followerName = trip.follower != null
        ? '${trip.follower!.firstname} ${trip.follower!.lastname}'
        : '';
    final followerSubtitle = trip.follower != null
        ? (trip.follower!.vehicleSummary != 'ไม่ระบุยานพาหนะ'
              ? 'ขับตาม: ${trip.follower!.vehicleSummary}'
              : 'คนขับผู้ช่วย (ขับตาม)')
        : '';

    final bool hasDrivers =
        trip.leader != null && trip.requestStatus != 'ยกเลิก';
    final int driverCount =
        (trip.leader != null ? 1 : 0) + (trip.follower != null ? 1 : 0);

    // Car details check
    final hasUserCar = trip.userCar != null;
    final carBrand = trip.userCar?.carBrand ?? '';
    final carModel = trip.userCar?.carModel ?? '';
    final carPlate = trip.userCar?.carPlate ?? '';
    final carColor = trip.userCar?.carColor ?? '';

    final carTitle = hasUserCar && (carBrand.isNotEmpty || carModel.isNotEmpty)
        ? '$carBrand $carModel'.trim()
        : (hasUserCar ? 'รถยนต์ของคุณ' : 'ไม่พบข้อมูลยานพาหนะ');

    final carSubtitle = hasUserCar && carColor.isNotEmpty
        ? 'สี $carColor'
        : (hasUserCar ? 'รถยนต์ส่วนบุคคล' : 'ไม่มีข้อมูลรายละเอียดรถ');

    final pickupPoint = _isLoadingPickupAddress
        ? 'กำลังค้นหาชื่อสถานที่...'
        : (_pickupAddress ?? 'ไม่พบชื่อสถานที่');
    final dropoffPoint = _isLoadingDropoffAddress
        ? 'กำลังค้นหาชื่อสถานที่...'
        : (_dropoffAddress ?? 'ไม่พบชื่อสถานที่');

    final paymentMethodText = trip.paymentMethod == 2
        ? 'กระเป๋าเงิน SafeSeat'
        : 'ชำระด้วยเงินสด';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'รายละเอียดบริการ',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Order details header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'การเดินทาง $orderCode',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: trip.requestStatus == 'เสร็จสิ้น'
                            ? AppTheme.successColor.withValues(alpha: 0.1)
                            : trip.requestStatus == 'ยกเลิก'
                            ? AppTheme.errorColor.withValues(alpha: 0.1)
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trip.requestStatus,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: trip.requestStatus == 'เสร็จสิ้น'
                              ? AppTheme.successColor
                              : trip.requestStatus == 'ยกเลิก'
                              ? AppTheme.errorColor
                              : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Map Preview Area with overlapping location info card
              Container(
                height: 320,
                margin: const EdgeInsets.symmetric(horizontal: 20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: pickupLatLng,
                          initialZoom: 14.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.safeseat.mini',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: [pickupLatLng, dropoffLatLng],
                                color: AppTheme.primaryColor,
                                strokeWidth: 4.0,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: pickupLatLng,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppTheme.pickupColor,
                                  size: 32,
                                ),
                              ),
                              Marker(
                                point: dropoffLatLng,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.flag,
                                  color: AppTheme.dropoffColor,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Overlay Card
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Timeline indicators
                              Column(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: AppTheme.pickupColor,
                                    size: 20,
                                  ),
                                  Container(
                                    width: 1.5,
                                    height: 20,
                                    color: Colors.grey[300],
                                  ),
                                  const Icon(
                                    Icons.flag,
                                    color: AppTheme.dropoffColor,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              // Location text details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'จุดรับ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    Text(
                                      pickupPoint,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _isLoadingPickupAddress
                                            ? AppTheme.textMuted
                                            : AppTheme.textPrimary,
                                        fontStyle: _isLoadingPickupAddress
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'จุดส่ง',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    Text(
                                      dropoffPoint,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _isLoadingDropoffAddress
                                            ? AppTheme.textMuted
                                            : AppTheme.textPrimary,
                                        fontStyle: _isLoadingDropoffAddress
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Distance info
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'ระยะทาง',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${trip.reqDistance.toStringAsFixed(1)} กม.',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F3D8A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: InkWell(
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text(
                      'ข้อมูลสถานที่และแผนที่ © OpenStreetMap contributors',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),

              // User remark / note if present
              if (trip.note != null && trip.note!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 20.0,
                    top: 12.0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sticky_note_2_outlined,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'หมายเหตุ: ${trip.note!.trim()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3. Driver Info Section
              Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 24.0,
                  bottom: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ข้อมูลคนขับของคุณ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasDrivers ? '$driverCount คน' : 'ยังไม่มีคนขับ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Driver profiles row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: hasDrivers
                    ? Row(
                        children: [
                          // Driver 1 (Leader)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  DriverAvatar(
                                    imageUrl: trip.leader?.resolvedImageUrl,
                                    fallbackName: leaderName,
                                    radius: 36,
                                    badgeText: 'D1',
                                    badgeColor: AppTheme.accentColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    leaderName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    leaderSubtitle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (trip.leader?.rating != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppTheme.borderColor,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            trip.leader!.rating!
                                                .toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Driver 2 (Follower)
                          Expanded(
                            child: trip.follower != null
                                ? Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFF1F5F9),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.02,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        DriverAvatar(
                                          imageUrl:
                                              trip.follower?.resolvedImageUrl,
                                          fallbackName: followerName,
                                          radius: 36,
                                          badgeText: 'D2',
                                          badgeColor: const Color(0xFF475569),
                                          defaultIcon: Icons.motorcycle,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          followerName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          followerSubtitle,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (trip.follower?.rating != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppTheme.borderColor,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  trip.follower!.rating!
                                                      .toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFF1F5F9),
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.person_outline_rounded,
                                            size: 36,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'ไม่มีผู้ช่วยคนขับ',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.no_accounts_rounded,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ไม่มีข้อมูลคนขับ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trip.requestStatus == 'ยกเลิก'
                                  ? 'รายการเรียกรถนี้ถูกยกเลิกแล้ว'
                                  : 'ยังไม่มีคนขับกดรับงานนี้',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),

              // 4. Vehicle Details Section
              Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 24.0,
                  bottom: 12.0,
                ),
                child: const Text(
                  'ข้อมูลยานพาหนะของคุณ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Color(0xFF475569),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    carTitle,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (carPlate.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      carPlate,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              carSubtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Payment details card
              Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 24.0,
                  bottom: 12.0,
                ),
                child: const Text(
                  'รายละเอียดค่าบริการ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ค่าบริการรวม',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                            Text(
                              '฿${trip.requestFee.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          border: Border(
                            top: BorderSide(color: Colors.grey[100]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                paymentMethodText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.verified,
                              color: AppTheme.accentColor,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Action buttons (only show if not cancelled)
              if (trip.requestStatus != 'ยกเลิก')
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => HistoryTripReviewScreen(
                                  trip: trip,
                                  existingReviews: _hasReviewed
                                      ? _existingReviews
                                      : null,
                                  pickupAddress: _pickupAddress,
                                  dropoffAddress: _dropoffAddress,
                                ),
                              ),
                            );
                            _checkReviewStatus();
                          },
                          icon: Icon(
                            _hasReviewed
                                ? Icons.rate_review_rounded
                                : Icons.star_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            _hasReviewed ? 'ดูรีวิวของคุณ' : 'รีวิวคนขับ',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasReviewed
                                ? const Color(0xFF475569)
                                : AppTheme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (_hasReported && _existingReport != null) {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HistoryReportDetailsScreen(
                                        report: _existingReport!,
                                      ),
                                ),
                              );
                            } else {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => HistoryTripReportScreen(
                                    trip: trip,
                                    pickupAddress: _pickupAddress,
                                    dropoffAddress: _dropoffAddress,
                                  ),
                                ),
                              );
                            }
                            _checkReportStatus();
                          },
                          icon: Icon(
                            _hasReported
                                ? Icons.assignment_turned_in_rounded
                                : Icons.error_outline_rounded,
                            color: _hasReported
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                          label: Text(
                            _hasReported
                                ? 'ดูรายงานที่คุณแจ้งไว้'
                                : 'รายงานคนขับ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _hasReported
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _hasReported
                                ? const Color(0xFFEFF6FF)
                                : AppTheme.backgroundColor,
                            side: BorderSide(
                              color: _hasReported
                                  ? const Color(0xFF93C5FD)
                                  : AppTheme.borderColor,
                              width: _hasReported ? 1.5 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
