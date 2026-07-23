import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/features/request_driver/controllers/request_driver_controller.dart';
import 'package:safeseat_mini/features/profile/controllers/profile_controller.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/core/services/route_service.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';
import 'package:share_plus/share_plus.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  final int requestId;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickupLatLng;
  final LatLng dropoffLatLng;
  final String carDetails;
  final double price;
  final RequestDriverModel? initialRequestData;

  const ActiveTripScreen({
    super.key,
    required this.requestId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLatLng,
    required this.dropoffLatLng,
    required this.carDetails,
    required this.price,
    this.initialRequestData,
  });

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  final MapController _mapController = MapController();
  Timer? _statusTimer;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;
  LatLng? _driverLatLng;
  
  String _currentStatus = 'going to pickup';
  DriverProfileModel? _leaderDriver;
  DriverProfileModel? _followerDriver;
  double _tripPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _tripPrice = widget.price;
    
    // Populate from initial data if available
    if (widget.initialRequestData != null) {
      _parseRequestData(widget.initialRequestData!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoute();
      _startStatusPolling();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _parseRequestData(RequestDriverModel data) {
    setState(() {
      _currentStatus = data.requestStatus;
      _leaderDriver = data.leader;
      _followerDriver = data.follower;
      _tripPrice = data.requestFee;
 
      // Check if buddyteam coordinates exist
      final buddyteam = data.buddyTeam;
      if (buddyteam != null) {
        final double? lat = buddyteam.currentLocLat;
        final double? lng = buddyteam.currentLocLng;
        
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          _driverLatLng = LatLng(lat, lng);
        }
      }
    });

    // If trip completed, stop polling and refresh wallet
    if (_currentStatus == 'เสร็จสิ้น') {
      _statusTimer?.cancel();
      _refreshUserWallet();
    }
  }

  Future<void> _loadRoute() async {
    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final routeDetails = await RouteService.getRouteDetails(widget.pickupLatLng, widget.dropoffLatLng);
      if (mounted) {
        setState(() {
          _routePoints = routeDetails?.points ?? [widget.pickupLatLng, widget.dropoffLatLng];
          _isLoadingRoute = false;
        });
        
        _fitMapBounds();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routePoints = [widget.pickupLatLng, widget.dropoffLatLng];
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _fitMapBounds() {
    if (_routePoints.isEmpty) return;
    
    // Fit map bounds to show both pickup and dropoff
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(widget.pickupLatLng, widget.dropoffLatLng),
        padding: const EdgeInsets.symmetric(horizontal: 60.0, vertical: 80.0),
      ),
    );
  }

  void _startStatusPolling() {
    // Poll immediately on start
    _checkStatus();

    // Setup periodic polling every 5 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    try {
      final request = await ref
          .read(requestDriverControllerProvider.notifier)
          .checkRequestStatus(widget.requestId);

      if (request != null && mounted) {
        _parseRequestData(request);
      }
    } catch (e) {
      debugPrint('Error polling active trip status: $e');
    }
  }

  void _refreshUserWallet() {
    final user = ref.read(userProvider);
    if (user != null) {
      ref.read(profileControllerProvider.notifier).getUserProfile(user.phoneNo);
    }
  }

  void _showCallDialog(String role, String name, String? phoneNo) {
    if (phoneNo == null || phoneNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีเบอร์โทรศัพท์สำหรับคนขับคนนี้')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'ติดต่อ$role',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คนขับ: $name', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('เบอร์โทรศัพท์: $phoneNo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phoneNo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('คัดลอกเบอร์โทรศัพท์เรียบร้อยแล้ว')),
              );
              Navigator.of(context).pop();
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy, size: 18),
                SizedBox(width: 4),
                Text('คัดลอกเบอร์'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('กำลังจำลองสายโทรไปที่ $phoneNo...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('โทรออก'),
          ),
        ],
      ),
    );
  }

  void _shareTripLink() {
    final String shareUrl = 'http://localhost:5000/trip?id=${widget.requestId}';
    Share.share(
      'ฉันกำลังเดินทางด้วย SafeSeat! คุณสามารถติดตามพิกัดสดและสถานะการเดินทางของฉันได้ที่นี่: $shareUrl',
      subject: 'ติดตามการเดินทางของฉัน (SafeSeat)',
    );
  }

  // Map status string to Thai display text and color/icon
  Map<String, dynamic> _getStatusUI() {
    final status = _currentStatus;
    
    if (status == 'กำลังค้นหาคนขับ') {
      return {
        'title': 'กำลังค้นหาคนขับ',
        'desc': 'ระบบกำลังค้นหาคู่หูคนขับที่อยู่ใกล้ที่สุดสำหรับคุณ',
        'color': const Color(0xFF94A3B8),
        'icon': Icons.location_searching,
        'badgeColor': const Color(0xFFF1F5F9),
      };
    } else if (status == 'กำลังไปรับ') {
      return {
        'title': 'คนขับกำลังมารับคุณ',
        'desc': 'คนขับหลักและรถผู้ช่วยกำลังเดินทางไปยังจุดรับของคุณ',
        'color': const Color(0xFF2563EB),
        'icon': Icons.directions_run_outlined,
        'badgeColor': const Color(0xFFDBEAFE),
      };
    } else if (status == 'ถึงจุดนัดหมาย') {
      return {
        'title': 'คนขับมาถึงจุดนัดหมายแล้ว',
        'desc': 'คนขับเดินทางมาถึงจุดนัดหมายแล้ว กรุณาไปพบคนขับที่จุดจอดรถ',
        'color': const Color(0xFFD97706),
        'icon': Icons.pin_drop,
        'badgeColor': const Color(0xFFFEF3C7),
      };
    } else if (status == 'กำลังเดินทาง') {
      return {
        'title': 'กำลังนำทางไปปลายทาง',
        'desc': 'อยู่ระหว่างการเดินทางไปยังจุดหมายปลายทางของคุณอย่างปลอดภัย',
        'color': const Color(0xFF7C3AED),
        'icon': Icons.local_taxi,
        'badgeColor': const Color(0xFFF3E8FF),
      };
    } else if (status == 'เสร็จสิ้น') {
      return {
        'title': 'การเดินทางเสร็จสิ้น',
        'desc': 'ถึงจุดหมายปลายทางเรียบร้อยแล้ว ขอบคุณที่เดินทางกับเรา',
        'color': const Color(0xFF059669),
        'icon': Icons.check_circle_outline,
        'badgeColor': const Color(0xFFD1FAE5),
      };
    } else {
      // Fallback
      return {
        'title': _currentStatus,
        'desc': 'สถานะการเดินทางได้รับการอัปเดต',
        'color': AppTheme.primaryColor,
        'icon': Icons.map,
        'badgeColor': Colors.blueGrey[50],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusUI = _getStatusUI();
    final isTripCompleted = _currentStatus == 'เสร็จสิ้น';

    final List<Marker> markers = [
      // Pickup Pin
      Marker(
        point: widget.pickupLatLng,
        width: 80,
        height: 60,
        child: const Column(
          children: [
            Icon(
              Icons.location_on,
              color: Colors.red,
              size: 36,
            ),
          ],
        ),
      ),
      // Dropoff Pin
      Marker(
        point: widget.dropoffLatLng,
        width: 80,
        height: 60,
        child: const Column(
          children: [
            Icon(
              Icons.location_on,
              color: Color(0xFF10B981),
              size: 36,
            ),
          ],
        ),
      ),
    ];

    // Add Driver team pin if location exists
    if (_driverLatLng != null) {
      markers.add(
        Marker(
          point: _driverLatLng!,
          width: 60,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: statusUI['color'] as Color, width: 3),
            ),
            child: Center(
              child: Icon(
                Icons.navigation,
                color: statusUI['color'] as Color,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Map component (fills screen)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.pickupLatLng,
                initialZoom: 14.5,
                maxZoom: 18.0,
                minZoom: 5.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safeseat.mini',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: statusUI['color'] as Color,
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // Route loading indicator
          if (_isLoadingRoute)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),

          // 2. Map actions (Reset zoom/Recenter)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter_btn',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E293B),
              elevation: 4,
              onPressed: _fitMapBounds,
              shape: const CircleBorder(),
              child: const Icon(Icons.my_location),
            ),
          ),

          // Share Trip Button
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 72,
            child: FloatingActionButton.small(
              heroTag: 'share_trip_btn',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              elevation: 4,
              onPressed: _shareTripLink,
              shape: const CircleBorder(),
              child: const Icon(Icons.share),
            ),
          ),

          // 3. Live tracking indicator overlay
          if (!isTripCompleted)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).padding.top + 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'กำลังติดตามพิกัดสด',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Bottom Info Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusUI['badgeColor'] as Color,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              statusUI['icon'] as IconData,
                              color: statusUI['color'] as Color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusUI['title'] as String,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: statusUI['color'] as Color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  statusUI['desc'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const Divider(height: 32),

                      // Driver Profiles / Vehicle Card
                      if (_leaderDriver != null) ...[
                        const Text(
                          'ทีมคู่หูคนขับของคุณ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            children: [
                              // Leader Info Row
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    child: const Icon(Icons.person, color: AppTheme.primaryColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'คนขับหลัก: ${_leaderDriver!.firstname} ${_leaderDriver!.lastname}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          'ทะเบียนรถไล่ตาม: ${_leaderDriver!.licensePlate ?? 'ไม่ระบุ'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.phone, color: Colors.green),
                                    onPressed: () => _showCallDialog(
                                      'คนขับหลัก',
                                      '${_leaderDriver!.firstname} ${_leaderDriver!.lastname}',
                                      _leaderDriver!.phoneNo,
                                    ),
                                  ),
                                ],
                              ),
                              
                              if (_followerDriver != null) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Divider(color: Color(0xFFE2E8F0)),
                                ),
                                // Follower Info Row
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
                                      child: const Icon(Icons.motorcycle, color: Colors.blueGrey),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'คนขับรถผู้ช่วย: ${_followerDriver!.firstname} ${_followerDriver!.lastname}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const Text(
                                            'ขับรถผู้ช่วยติดตามคุณ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.phone, color: Colors.green),
                                      onPressed: () => _showCallDialog(
                                        'คนขับผู้ช่วย',
                                        '${_followerDriver!.firstname} ${_followerDriver!.lastname}',
                                        _followerDriver!.phoneNo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Fare summary card
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ยานพาหนะที่จะให้ขับ',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.carDetails,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'ค่าบริการสุทธิ',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '฿${_tripPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Actions Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isTripCompleted
                              ? () {
                                  Navigator.of(context).pop(); // Pops this screen back to HomeScreen
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTripCompleted ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: isTripCompleted ? 4 : 0,
                          ),
                          child: Text(
                            isTripCompleted ? 'กลับสู่หน้าหลัก' : 'กำลังนำทางโดยคนขับรถมืออาชีพ...',
                            style: const TextStyle(
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
        ],
      ),
    );
  }
}
