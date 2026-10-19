import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/services/geocoding_service.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/core/widgets/driver_avatar.dart';
import 'package:safeseat_mini/features/history/controllers/history_controller.dart';
import 'package:safeseat_mini/features/history/history_trip_details_screen.dart';
import 'package:safeseat_mini/features/history/history_report_details_screen.dart';
import 'package:safeseat_mini/features/request_driver/active_trip_screen.dart';
import 'package:safeseat_mini/features/request_driver/waiting_driver_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _selectedTab =
      0; // 0: กำลังดำเนินการ, 1: สำเร็จ, 2: ยกเลิกแล้ว, 3: รายงาน
  int _displayedCount = 5;
  static const String _loadingPlace = 'กำลังค้นหาสถานที่...';
  static const String _missingPlace = 'ไม่พบชื่อสถานที่';
  final Map<String, Future<String?>> _placeLookups = {};

  final List<String> _tabs = [
    'กำลังดำเนินการ',
    'สำเร็จ',
    'ยกเลิกแล้ว',
    'รายงาน',
  ];

  Future<void> _refreshHistory() async {
    // A refresh reuses cached names and allows failed lookups to retry after
    // GeocodingService's short failure cooldown.
    _placeLookups.clear();
    String type = 'active';
    if (_selectedTab == 1) {
      type = 'completed';
    } else if (_selectedTab == 2) {
      type = 'cancelled';
    }

    if (_selectedTab != 3) {
      ref.invalidate(historyListProvider(type));
    } else {
      ref.invalidate(userReportsListProvider);
    }
  }

  Future<String?> _placeLookup(double latitude, double longitude) {
    final key = '$latitude,$longitude';
    return _placeLookups.putIfAbsent(key, () {
      if (!latitude.isFinite ||
          !longitude.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180 ||
          (latitude == 0 && longitude == 0)) {
        return Future<String?>.value(null);
      }
      return GeocodingService.reverseGeocode(latitude, longitude);
    });
  }

  String _placeText(AsyncSnapshot<String?> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return _loadingPlace;
    final name = snapshot.data?.trim();
    return name == null || name.isEmpty ? _missingPlace : name;
  }

  Widget _withPlaceNames(
    Future<String?> pickupLookup,
    Future<String?> dropoffLookup,
    Widget Function(String pickup, String dropoff) builder,
  ) {
    return FutureBuilder<String?>(
      future: pickupLookup,
      builder: (context, pickupSnapshot) => FutureBuilder<String?>(
        future: dropoffLookup,
        builder: (context, dropoffSnapshot) =>
            builder(_placeText(pickupSnapshot), _placeText(dropoffSnapshot)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final String? profileImagePath = user?.profileImagePath;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHistory,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Image Top Left
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      profileImagePath != null && profileImagePath.isNotEmpty
                      ? NetworkImage(profileImagePath)
                      : null,
                  child: (profileImagePath == null || profileImagePath.isEmpty)
                      ? const Icon(Icons.person, size: 28, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),

                // Screen Title
                const Text(
                  'ประวัติการเดินทาง',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ติดตามสถานะและดูรายละเอียดทุกการเดินทางของคุณ',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),

                // Tabs Selection
                _buildTabs(),
                const SizedBox(height: 20),

                // Selected Tab Content
                _buildTabContent(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final isSelected = _selectedTab == idx;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTab = idx;
                  _displayedCount = 5;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTab == 3) {
      final reportsAsync = ref.watch(userReportsListProvider);

      return reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return _buildEmptyState(
              Icons.report_gmailerrorred_rounded,
              'ยังไม่มีรายงาน',
              'รายงานที่คุณส่งจะแสดงที่นี่',
            );
          }

          final visibleReports = reports.take(_displayedCount).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleReports.length,
                itemBuilder: (context, index) {
                  final report = visibleReports[index];
                  final dateStr = report.reportDate != null
                      ? '${report.reportDate!.day}/${report.reportDate!.month}/${report.reportDate!.year} • ${report.reportDate!.hour.toString().padLeft(2, '0')}:${report.reportDate!.minute.toString().padLeft(2, '0')}'
                      : '';

                  final statusColor = report.reportStatus == 'กำลังดำเนินการ'
                      ? AppTheme.warningColor
                      : AppTheme.successColor;

                  final statusBgColor = report.reportStatus == 'กำลังดำเนินการ'
                      ? AppTheme.warningColor.withValues(alpha: 0.1)
                      : AppTheme.successColor.withValues(alpha: 0.1);

                  // Extract reported driver info and clean detail
                  final rawDetail = report.reportDetail ?? '';
                  final idMatch = RegExp(
                    r'\[ID:\s*([^\]]+)\]',
                    caseSensitive: false,
                  ).firstMatch(rawDetail);
                  final List<String> reportedIds =
                      idMatch != null && idMatch.group(1) != null
                      ? idMatch
                            .group(1)!
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList()
                      : [];
                  final cleanDetail = rawDetail
                      .replaceAll(
                        RegExp(r'\[ID:\s*[^\]]+\]\s*', caseSensitive: false),
                        '',
                      )
                      .replaceAll(
                        RegExp(
                          r'\[เป้าหมาย:\s*[^\]]+\]\s*',
                          caseSensitive: false,
                        ),
                        '',
                      )
                      .trim();

                  String driverInfo = 'ไม่มีข้อมูลคนขับ';
                  final req = report.requestByUser;
                  if (req != null) {
                    final leader = req['leader'];
                    final follower = req['follower'];
                    final List<String> drivers = [];

                    if (reportedIds.isNotEmpty) {
                      if (leader != null &&
                          reportedIds.contains(leader['username'])) {
                        drivers.add(
                          'คนขับหลัก: ${leader['firstname']} ${leader['lastname']}',
                        );
                      }
                      if (follower != null &&
                          reportedIds.contains(follower['username'])) {
                        drivers.add(
                          'ผู้ช่วยคนขับ: ${follower['firstname']} ${follower['lastname']}',
                        );
                      }
                    } else {
                      if (leader != null) {
                        drivers.add(
                          'คนขับหลัก: ${leader['firstname']} ${leader['lastname']}',
                        );
                      }
                      if (follower != null) {
                        drivers.add(
                          'ผู้ช่วยคนขับ: ${follower['firstname']} ${follower['lastname']}',
                        );
                      }
                    }

                    if (drivers.isNotEmpty) {
                      driverInfo = drivers.join('\n');
                    }
                  }

                  final firstImageUrl =
                      (report.reportImagePath != null &&
                          report.reportImagePath!.isNotEmpty)
                      ? Supabase.instance.client.storage
                            .from('images')
                            .getPublicUrl(
                              report.reportImagePath!.split(',').first,
                            )
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                HistoryReportDetailsScreen(report: report),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusBgColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          report.reportStatus ??
                                              'กำลังดำเนินการ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    report.reportType,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    driverInfo,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF475569),
                                      height: 1.4,
                                    ),
                                  ),
                                  if (cleanDetail.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      cleanDetail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (firstImageUrl != null) ...[
                              const SizedBox(width: 16),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(
                                    firstImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.broken_image,
                                              size: 24,
                                            ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (reports.length > _displayedCount) ...[
                const SizedBox(height: 16),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _displayedCount += 5;
                      });
                    },
                    icon: const Icon(Icons.expand_more_rounded, size: 20),
                    label: Text(
                      'โหลดรายงานเพิ่มเติม (แสดงแล้ว ${visibleReports.length} จาก ${reports.length})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: const Color(0xFFEFF6FF),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => _buildLoadingState(),
        error: (err, stack) =>
            _buildErrorState(() => ref.invalidate(userReportsListProvider)),
      );
    }

    String type = 'active';
    if (_selectedTab == 1) {
      type = 'completed';
    } else if (_selectedTab == 2) {
      type = 'cancelled';
    }

    final historyAsync = ref.watch(historyListProvider(type));

    return historyAsync.when(
      data: (trips) {
        if (trips.isEmpty) {
          return _buildEmptyState(
            Icons.directions_car_filled_outlined,
            'ยังไม่มีการเดินทางในหมวดนี้',
            'เมื่อมีรายการใหม่ ข้อมูลจะแสดงที่นี่',
          );
        }

        final visibleTrips = trips.take(_displayedCount).toList();

        // Return list of trip cards with pagination
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleTrips.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final trip = visibleTrips[index];

                // Map status info
                Color statusColor = AppTheme.accentColor;
                Color statusBg = AppTheme.accentColor.withValues(alpha: 0.1);

                if (trip.requestStatus == 'เสร็จสิ้น') {
                  statusColor = AppTheme.successColor;
                  statusBg = AppTheme.successColor.withValues(alpha: 0.1);
                } else if (trip.requestStatus == 'ยกเลิก') {
                  statusColor = AppTheme.errorColor;
                  statusBg = AppTheme.errorColor.withValues(alpha: 0.1);
                }

                final driverName = trip.leader != null
                    ? '${trip.leader!.firstname} ${trip.leader!.lastname}'
                    : 'รอกำหนดคนขับ';

                final hasUserCar = trip.userCar != null;
                final carBrand = trip.userCar?.carBrand ?? '';
                final carModel = trip.userCar?.carModel ?? '';
                final carColor = trip.userCar?.carColor ?? '';
                final carPlate = trip.userCar?.carPlate ?? '';

                final carModelStr =
                    hasUserCar && (carBrand.isNotEmpty || carModel.isNotEmpty)
                    ? '$carBrand $carModel'.trim()
                    : (hasUserCar ? 'รถยนต์ของคุณ' : 'ไม่พบข้อมูลรถ');

                final carColorPlateStr =
                    hasUserCar && (carColor.isNotEmpty || carPlate.isNotEmpty)
                    ? [
                        if (carColor.isNotEmpty) 'สี$carColor',
                        if (carPlate.isNotEmpty) carPlate,
                      ].join(' • ')
                    : '';

                // Only the currently displayed cards start address lookups.
                return _withPlaceNames(
                  _placeLookup(trip.pickupLatitude, trip.pickupLongitude),
                  _placeLookup(trip.dropoffLatitude, trip.dropoffLongitude),
                  (pickupPlace, dropoffPlace) => _buildTripCard(
                    driverName: driverName,
                    driverImageUrl: trip.leader?.resolvedImageUrl,
                    driverRating: trip.leader?.rating,
                    orderCode:
                        '#ORD${trip.requestId.toString().padLeft(4, '0')}',
                    status: trip.requestStatus,
                    statusColor: statusColor,
                    statusBg: statusBg,
                    pickupPoint: pickupPlace,
                    dropoffPoint: dropoffPlace,
                    distanceText:
                        'ระยะทาง ${trip.reqDistance.toStringAsFixed(1)} กม.',
                    carModel: carModelStr,
                    carColorPlate: carColorPlateStr,
                    onViewDetails: () {
                      final status = trip.requestStatus;
                      if (status == 'รอคนขับ' || status == 'กำลังค้นหาคนขับ') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => WaitingDriverScreen(
                              requestId: trip.requestId,
                              pickupAddress: pickupPlace,
                              dropoffAddress: dropoffPlace,
                              pickupLatLng: LatLng(
                                trip.pickupLatitude,
                                trip.pickupLongitude,
                              ),
                              dropoffLatLng: LatLng(
                                trip.dropoffLatitude,
                                trip.dropoffLongitude,
                              ),
                              carDetails: carModelStr,
                              price: trip.requestFee,
                            ),
                          ),
                        );
                      } else if (status == 'กำลังไปรับ' ||
                          status == 'ถึงจุดนัดหมาย' ||
                          status == 'ถึงจุดรับแล้ว' ||
                          status == 'กำลังเดินทาง' ||
                          status == 'ระหว่างเดินทาง') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ActiveTripScreen(
                              requestId: trip.requestId,
                              pickupAddress: pickupPlace,
                              dropoffAddress: dropoffPlace,
                              pickupLatLng: LatLng(
                                trip.pickupLatitude,
                                trip.pickupLongitude,
                              ),
                              dropoffLatLng: LatLng(
                                trip.dropoffLatitude,
                                trip.dropoffLongitude,
                              ),
                              carDetails: carModelStr,
                              price: trip.requestFee,
                              initialRequestData: trip,
                            ),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                HistoryTripDetailsScreen(trip: trip),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
            if (trips.length > _displayedCount) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _displayedCount += 5;
                    });
                  },
                  icon: const Icon(Icons.expand_more_rounded, size: 20),
                  label: Text(
                    'โหลดประวัติเพิ่มเติม (แสดงแล้ว ${visibleTrips.length} จาก ${trips.length})',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'ข้อมูลสถานที่ © OpenStreetMap contributors',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => _buildLoadingState(),
      error: (err, stack) =>
          _buildErrorState(() => ref.invalidate(historyListProvider(type))),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
            child: Icon(icon, size: 30, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _buildErrorState(VoidCallback retry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 36,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'โหลดข้อมูลไม่สำเร็จ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard({
    required String driverName,
    String? driverImageUrl,
    double? driverRating,
    required String orderCode,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required String pickupPoint,
    required String dropoffPoint,
    required String distanceText,
    required String carModel,
    required String carColorPlate,
    required VoidCallback onViewDetails,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of Card (Driver Info + Status Badge)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (driverImageUrl != null && driverImageUrl.isNotEmpty)
                  DriverAvatar(
                    imageUrl: driverImageUrl,
                    fallbackName: driverName,
                    radius: 20,
                    badgeText: 'D1',
                    badgeColor: AppTheme.accentColor,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_outlined,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              driverName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (driverRating != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFEF3C7),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    driverRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        orderCode,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Stack(
              children: [
                // Connecting vertical line
                Positioned(
                  left: 11,
                  top: 26,
                  bottom: 26,
                  child: Container(width: 2, color: AppTheme.borderColor),
                ),
                Column(
                  children: [
                    // Pickup Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2.0),
                          child: Icon(
                            Icons.location_on,
                            color: AppTheme.pickupColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'จุดรับ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pickupPoint,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Distance indicator row
                    Row(
                      children: [
                        const SizedBox(width: 36),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            distanceText,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dropoff Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2.0),
                          child: Icon(
                            Icons.flag,
                            color: AppTheme.dropoffColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'จุดหมายปลายทาง',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dropoffPoint,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),

          // Footer (Car details + button)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final vehicle = Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_car,
                          color: Color(0xFF1E3A8A),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            carModel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            carColorPlate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final detailsButton = ElevatedButton(
                  onPressed: onViewDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ดูรายละเอียด',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                );

                if (constraints.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      vehicle,
                      const SizedBox(height: 12),
                      detailsButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: vehicle),
                    const SizedBox(width: 12),
                    detailsButton,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
