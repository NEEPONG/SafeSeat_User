import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/features/history/controllers/history_controller.dart';
import 'package:safeseat_mini/features/history/history_trip_details_screen.dart';
import 'package:safeseat_mini/features/history/history_report_details_screen.dart';
import 'package:safeseat_mini/features/request_driver/active_trip_screen.dart';
import 'package:safeseat_mini/features/request_driver/waiting_driver_screen.dart';
import 'package:latlong2/latlong.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _selectedTab = 0; // 0: กำลังดำเนินการ, 1: สำเร็จ, 2: ยกเลิกแล้ว, 3: รายงาน

  final List<String> _tabs = [
    'กำลังดำเนินการ',
    'สำเร็จ',
    'ยกเลิกแล้ว',
    'รายงาน',
  ];

  Future<void> _refreshHistory() async {
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final String? profileImagePath = user?.profileImagePath;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHistory,
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Image Top Left
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: profileImagePath != null && profileImagePath.isNotEmpty
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
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),

                // Tabs Selection
                _buildTabs(),
                const SizedBox(height: 20),

                // Selected Tab Content
                _buildTabContent(),
                const SizedBox(height: 28),

                // Recommendation Header
                const Text(
                  'คุณอาจชอบสิ่งเหล่านี้',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),

                // Recommendation Items
                _buildRecommendations(),
                const SizedBox(height: 16),
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
          bottom: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1,
          ),
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

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = idx;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
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
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.report_gmailerrorred_rounded,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ไม่มีรายงานการเดินทาง',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final dateStr = report.reportDate != null
                  ? '${report.reportDate!.day}/${report.reportDate!.month}/${report.reportDate!.year} • ${report.reportDate!.hour.toString().padLeft(2, '0')}:${report.reportDate!.minute.toString().padLeft(2, '0')}'
                  : '';
              
              final statusColor = report.reportStatus == 'กำลังดำเนินการ'
                  ? const Color(0xFFF97316)
                  : const Color(0xFF10B981);
                  
              final statusBgColor = report.reportStatus == 'กำลังดำเนินการ'
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFECFDF5);

              // Extract driver names from requestByUser map
              String driverInfo = 'ไม่มีข้อมูลคนขับ';
              final req = report.requestByUser;
              if (req != null) {
                final leader = req['leader'];
                final follower = req['follower'];
                final List<String> drivers = [];
                if (leader != null) {
                  drivers.add('คนขับหลัก: ${leader['firstname']} ${leader['lastname']}');
                }
                if (follower != null) {
                  drivers.add('ผู้ติดตาม: ${follower['firstname']} ${follower['lastname']}');
                }
                if (drivers.isNotEmpty) {
                  driverInfo = drivers.join('\n');
                }
              }

              // Parse image thumbnail path if exists
              String? firstImageUrl;
              if (report.reportImagePath != null && report.reportImagePath!.isNotEmpty) {
                final paths = report.reportImagePath!.split(',').where((p) => p.trim().isNotEmpty).toList();
                if (paths.isNotEmpty) {
                  firstImageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(paths.first);
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => HistoryReportDetailsScreen(report: report),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      report.reportStatus ?? 'กำลังดำเนินการ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
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
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                driverInfo,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                  height: 1.4,
                                ),
                              ),
                              if (report.reportDetail != null && report.reportDetail!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  report.reportDetail!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
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
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(
                                firstImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24),
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
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'เกิดข้อผิดพลาดในการโหลดรายงาน: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
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
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car_filled_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'ไม่มีประวัติการเดินทางในขณะนี้',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        // Return list of trip cards
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trips.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final trip = trips[index];
            
            // Map status info
            Color statusColor = const Color(0xFF3B82F6);
            Color statusBg = const Color(0xFFDBEAFE);
            
            if (trip.requestStatus == 'เสร็จสิ้น') {
              statusColor = const Color(0xFF10B981);
              statusBg = const Color(0xFFD1FAE5);
            } else if (trip.requestStatus == 'ยกเลิก') {
              statusColor = const Color(0xFFEF4444);
              statusBg = const Color(0xFFFEE2E2);
            }

            final driverName = trip.leader != null 
                ? '${trip.leader!.firstname} ${trip.leader!.lastname}'
                : 'รอกำหนดคนขับ';

            final carBrand = trip.userCar != null ? trip.userCar!.carBrand : '';
            final carModel = trip.userCar != null ? trip.userCar!.carModel : '';
            final carColor = trip.userCar != null ? trip.userCar!.carColor : '';
            final carPlate = trip.userCar != null ? trip.userCar!.carPlate : '';

            final carModelStr = carBrand.isNotEmpty || carModel.isNotEmpty
                ? '$carBrand $carModel'.trim()
                : 'Tesla Model 3'; // Fallback to mockup placeholder matching screenshot

            final carColorPlateStr = carColor.isNotEmpty || carPlate.isNotEmpty
                ? '$carColor • $carPlate'.trim()
                : 'สีขาว • กข 1234'; // Fallback to mockup placeholder matching screenshot

            // Format coordinates or note for pickup/dropoff places
            final String pickupPlace = trip.note != null && trip.note!.isNotEmpty
                ? trip.note!
                : 'ผับคุณหนูนิ่มประจำเชียงใหม่'; // Fallback to mockup placeholder matching screenshot
            
            const String dropoffPlace = 'จุดหมายปลายทางของการเดินทาง'; // Fallback placeholder matching screenshot

            return _buildTripCard(
              driverName: driverName,
              orderCode: '#ORD${trip.requestId.toString().padLeft(4, '0')}',
              status: trip.requestStatus,
              statusColor: statusColor,
              statusBg: statusBg,
              pickupPoint: pickupPlace,
              dropoffPoint: dropoffPlace,
              distanceText: '${trip.reqDistance.toStringAsFixed(1)} Km. Estimate 20 Min',
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
                        pickupLatLng: LatLng(trip.pickupLatitude, trip.pickupLongitude),
                        dropoffLatLng: LatLng(trip.dropoffLatitude, trip.dropoffLongitude),
                        carDetails: carModelStr,
                        price: trip.requestFee,
                        initialRequestData: trip,
                      ),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => HistoryTripDetailsScreen(trip: trip),
                    ),
                  );
                }
              },
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'เกิดข้อผิดพลาดในการโหลดข้อมูล: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard({
    required String driverName,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of Card (Driver Info + Status Badge)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Car Circle Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_outlined,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        orderCode,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  child: Container(
                    width: 2,
                    color: const Color(0xFFBFDBFE),
                  ),
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
                            color: Color(0xFF2563EB),
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
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pickupPoint,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
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
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          distanceText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
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
                            color: Color(0xFFEF4444),
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
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dropoffPoint,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
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
          const Divider(
            color: Color(0xFFF1F5F9),
            height: 1,
            thickness: 1,
          ),

          // Footer (Car details + button)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Car rounded display box
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        carColorPlate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // "ดูรายละเอียด" Button
                ElevatedButton(
                  onPressed: onViewDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ดูรายละเอียด',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Column(
      children: [
        // Grid of two side by side cards
        Row(
          children: [
            Expanded(
              child: _buildImageCard(
                imageUrl: 'https://images.unsplash.com/photo-1540962351504-03099e0a754b?w=400',
                title: 'SafeSeat Pro',
                subtitle: 'เดินทางอย่างมั่นใจ',
                height: 180,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildImageCard(
                imageUrl: 'https://images.unsplash.com/photo-1524522173746-f628baad3644?w=400',
                title: 'Smart Tracking',
                subtitle: 'ติดตามได้ทุกที่',
                height: 180,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Large full-width banner
        _buildImageCard(
          imageUrl: 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800',
          title: 'ส่วนลดพิเศษ 20%',
          subtitle: 'สำหรับการเดินทางครั้งต่อไปของคุณ',
          height: 140,
        ),
      ],
    );
  }

  Widget _buildImageCard({
    required String imageUrl,
    required String title,
    required String subtitle,
    required double height,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Image
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFE2E8F0),
                    child: const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black87,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Text Overlays
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
