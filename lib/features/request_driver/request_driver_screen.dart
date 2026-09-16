import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/features/profile/edit_profile_screen.dart';
import 'package:safeseat_mini/features/request_driver/controllers/request_driver_controller.dart';
import 'package:safeseat_mini/features/request_driver/select_location_screen.dart';
import 'package:safeseat_mini/features/request_driver/request_driver_details_screen.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';

class RequestDriverScreen extends ConsumerStatefulWidget {
  const RequestDriverScreen({super.key});

  @override
  ConsumerState<RequestDriverScreen> createState() => _RequestDriverScreenState();
}

class _RequestDriverScreenState extends ConsumerState<RequestDriverScreen> {
  final MapController _mapController = MapController();
  bool _isLoadingHome = false;

  void _navigateToSelectLocation({required bool isPickup}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelectLocationScreen(isPickup: isPickup),
      ),
    );
  }

  Future<void> _handleQuickSelectHome() async {
    final user = ref.read(userProvider);
    final homeDisplayName = user?.homeDisplayName;
    if (homeDisplayName == null || homeDisplayName.trim().isEmpty) {
      final goToProfile = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.home_outlined, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('ยังไม่ได้ตั้งค่าที่อยู่บ้าน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'คุณยังไม่ได้บันทึกสถานที่ตั้งต้น/บ้านไว้ในโปรไฟล์ ต้องการไปตั้งค่าตอนนี้หรือไม่?',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ไว้ทีหลัง', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ไปตั้งค่าโปรไฟล์', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (goToProfile == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        );
      }
      return;
    }

    // 1. If exact pinned LatLng is available in profile, use it directly (100% accurate!)
    if (user?.homeLatLng != null) {
      final latLng = user!.homeLatLng!;
      ref.read(requestDriverControllerProvider.notifier).setDropoff(homeDisplayName, latLng);
      _mapController.move(latLng, 15.0);
      AppSnackBar.showSuccess(context, 'ตั้งปลายทางกลับบ้านเรียบร้อยแล้ว');
      return;
    }

    // 2. Fallback to geocoding if only plain string was saved
    setState(() {
      _isLoadingHome = true;
    });

    try {
      final searchUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(homeDisplayName)}&format=json&limit=1',
      );
      final response = await http.get(searchUrl, headers: {
        'User-Agent': 'SafeSeatMiniApp/1.0',
        'Accept-Language': 'th,en',
      });
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          final latLng = LatLng(lat, lon);
          ref.read(requestDriverControllerProvider.notifier).setDropoff(homeDisplayName, latLng);
          _mapController.move(latLng, 15.0);
          if (mounted) {
            setState(() {
              _isLoadingHome = false;
            });
            AppSnackBar.showSuccess(context, 'ตั้งปลายทางกลับบ้านเรียบร้อยแล้ว');
          }
          return;
        }
      }
    } catch (_) {}

    // Fallback coordinates if geocode is unavailable
    final fallbackLatLng = const LatLng(18.8972, 99.0112);
    ref.read(requestDriverControllerProvider.notifier).setDropoff(homeDisplayName, fallbackLatLng);
    if (mounted) {
      setState(() {
        _isLoadingHome = false;
      });
      AppSnackBar.showSuccess(context, 'ตั้งปลายทางกลับบ้านเรียบร้อยแล้ว');
    }
  }

  Future<void> _handleSetCurrentLocationAsPickup() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppSnackBar.showWarning(context, 'กรุณาเปิดบริการระบุตำแหน่ง (GPS)');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppSnackBar.showWarning(context, 'สิทธิ์การเข้าถึงตำแหน่งถูกปฏิเสธ');
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(position.latitude, position.longitude);

      // Reverse geocode
      String shortName = 'ตำแหน่งปัจจุบัน';
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1',
        );
        final res = await http.get(url, headers: {
          'User-Agent': 'SafeSeatMiniApp/1.0',
          'Accept-Language': 'th,en',
        });
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final displayName = data['display_name'] as String?;
          if (displayName != null) {
            final parts = displayName.split(',');
            shortName = parts.take(2).join(', ').trim();
          }
        }
      } catch (_) {}

      ref.read(requestDriverControllerProvider.notifier).setPickup(shortName, latLng);
      _mapController.move(latLng, 16.0);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'อัปเดตจุดรับเป็นตำแหน่งปัจจุบันแล้ว');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'ไม่สามารถระบุตำแหน่งปัจจุบันได้');
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final reqState = ref.watch(requestDriverControllerProvider);
    final themeColor = AppTheme.primaryColor;

    // Decide map center based on pickup or default to Maejo
    LatLng mapCenter = const LatLng(18.8972, 99.0112);
    if (reqState.pickupLatLng != null) {
      mapCenter = reqState.pickupLatLng!;
    }

    // Build markers list
    final List<Marker> markers = [];
    if (reqState.pickupLatLng != null) {
      markers.add(
        Marker(
          point: reqState.pickupLatLng!,
          width: 100,
          height: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'จุดรับ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 32,
              ),
            ],
          ),
        ),
      );
    }
    if (reqState.dropoffLatLng != null) {
      markers.add(
        Marker(
          point: reqState.dropoffLatLng!,
          width: 100,
          height: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'จุดส่ง',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(
                Icons.location_on,
                color: Color(0xFF10B981),
                size: 32,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Widget
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 15.0,
              maxZoom: 18.0,
              minZoom: 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safeseat.mini',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // 2. Custom Rounded Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF1E293B),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From: Pickup Location Row
                  InkWell(
                    onTap: () => _navigateToSelectLocation(isPickup: true),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.red, width: 6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'จุดรับ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reqState.pickupAddress ?? 'ปักหมุดจุดรับ',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'จุดรับ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Divider(height: 24, color: Color(0xFFE2E8F0)),
                  ),

                  // To: Dropoff Location Row
                  InkWell(
                    onTap: () => _navigateToSelectLocation(isPickup: false),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF64748B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flag,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'จุดส่ง',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reqState.dropoffAddress ?? 'กรอกจุดส่งเพื่อค้นหา',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: reqState.dropoffAddress != null
                                        ? const Color(0xFF334155)
                                        : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Quick Destination Shortcuts Row
                  Row(
                    children: [
                      // 🏠 กลับบ้าน (Go Home)
                      Expanded(
                        child: InkWell(
                          onTap: _isLoadingHome ? null : _handleQuickSelectHome,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isLoadingHome
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(
                                          Icons.home,
                                          color: AppTheme.primaryColor,
                                          size: 16,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'กลับบ้าน 🏠',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        user?.homeDisplayName != null && user!.homeDisplayName!.trim().isNotEmpty
                                            ? user.homeDisplayName!
                                            : 'ตั้งค่าที่อยู่บ้าน',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: user?.homeDisplayName != null && user!.homeDisplayName!.trim().isNotEmpty
                                              ? const Color(0xFF64748B)
                                              : AppTheme.primaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 📍 จุดรับปัจจุบัน (GPS)
                      InkWell(
                        onTap: _handleSetCurrentLocationAsPickup,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'จุดรับปัจจุบัน',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // Call Driver Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: reqState.dropoffLatLng == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RequestDriverDetailsScreen(),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[200],
                        disabledForegroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'เรียกรถ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
