import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/core/widgets/driver_avatar.dart';
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

  // ~11 meters: ignore sub-meter GPS jitter so the route isn't recomputed
  // on every poll while the driver is stationary.
  static const double _locationTolerance = 0.0001;
  bool _hasFittedCamera = false;

  // Trip endpoints. Source of truth is the polled request data (server),
  // initialized from the constructor values and refreshed on every poll.
  late LatLng _pickupLatLng;
  late LatLng _dropoffLatLng;

  String _currentStatus = 'กำลังค้นหาคนขับ';
  DriverProfileModel? _leaderDriver;
  DriverProfileModel? _followerDriver;
  double _tripPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _pickupLatLng = widget.pickupLatLng;
    _dropoffLatLng = widget.dropoffLatLng;
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

  /// Maps backend/driver status variants to the canonical strings the UI understands.
  /// e.g. 'ถึงจุดรับแล้ว' == 'ถึงจุดนัดหมาย' and 'ระหว่างเดินทาง' == 'กำลังเดินทาง'
  String _normalizeStatus(String status) {
    switch (status) {
      case 'ถึงจุดรับแล้ว':
        return 'ถึงจุดนัดหมาย';
      case 'ระหว่างเดินทาง':
        return 'กำลังเดินทาง';
      default:
        return status;
    }
  }

  void _parseRequestData(RequestDriverModel data) {
    bool locationChanged = false;
    bool endpointsChanged = false;
    final String normalizedStatus = _normalizeStatus(data.requestStatus);
    final bool statusChanged = normalizedStatus != _currentStatus;

    setState(() {
      _currentStatus = normalizedStatus;
      _leaderDriver = data.leader;
      _followerDriver = data.follower;
      _tripPrice = data.requestFee;

      // Keep pickup/dropoff in sync with the server's request data
      // (the source of truth), so the pins/route never go stale.
      if (data.pickupLatitude != 0.0 || data.pickupLongitude != 0.0) {
        final newPickup = LatLng(data.pickupLatitude, data.pickupLongitude);
        if (newPickup != _pickupLatLng) {
          _pickupLatLng = newPickup;
          endpointsChanged = true;
        }
      }
      if (data.dropoffLatitude != 0.0 || data.dropoffLongitude != 0.0) {
        final newDropoff = LatLng(data.dropoffLatitude, data.dropoffLongitude);
        if (newDropoff != _dropoffLatLng) {
          _dropoffLatLng = newDropoff;
          endpointsChanged = true;
        }
      }
 
      // Check if buddyteam coordinates exist
      final buddyteam = data.buddyTeam;
      if (buddyteam != null) {
        final double? lat = buddyteam.currentLocLat;
        final double? lng = buddyteam.currentLocLng;
        
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          final newDriverPos = LatLng(lat, lng);
          // Only count as "moved" when the change is meaningful (GPS jitter
          // tolerance) so the route isn't recomputed every poll.
          final bool driverMoved = _driverLatLng == null ||
              (lat - _driverLatLng!.latitude).abs() > _locationTolerance ||
              (lng - _driverLatLng!.longitude).abs() > _locationTolerance;
          if (driverMoved) {
            _driverLatLng = newDriverPos;
            locationChanged = true;
          }
        }
      }
    });

    // Reload the route whenever the driver moves, the trip status changes,
    // or the server endpoints get corrected. Only re-fit the camera when the
    // trip layout itself changes (first load, status/direction, endpoints);
    // live driver movement should update the polyline without jumping the map.
    if (locationChanged || statusChanged || endpointsChanged) {
      _loadRoute(shouldFit: statusChanged || endpointsChanged || !_hasFittedCamera);
    }

    // If trip completed, stop polling and refresh wallet
    if (_currentStatus == 'เสร็จสิ้น') {
      _statusTimer?.cancel();
      _refreshUserWallet();
    }
  }

  Future<void> _loadRoute({bool shouldFit = true}) async {
    setState(() {
      _isLoadingRoute = true;
    });

    // 1. Determine current journey phase
    final bool isHeadingToPickup =
        _currentStatus == 'กำลังไปรับ' ||
        _currentStatus == 'กำลังค้นหาคนขับ' ||
        _currentStatus == 'รอคนขับ';

    final bool isArrivedAtPickup =
        _currentStatus == 'ถึงจุดนัดหมาย' ||
        _currentStatus == 'ถึงจุดรับแล้ว';

    final bool isCompleted =
        _currentStatus == 'เสร็จสิ้น' ||
        _currentStatus == 'completed';

    // 2. Determine start and target endpoints for current phase:
    // - Heading to Pickup: Driver -> Pickup (เส้นทางเดียวก่อน เพื่อไม่ให้ซูมไกลเกินไป)
    // - Arrived at Pickup: Pickup -> Destination
    // - In Transit (Driving to Destination): Driver Live Pos -> Destination
    // - Completed: Pickup -> Destination
    final startLatLng = _driverLatLng ?? _pickupLatLng;
    
    LatLng routeOrigin;
    LatLng routeDestination;

    if (isHeadingToPickup) {
      routeOrigin = startLatLng;
      routeDestination = _pickupLatLng;
    } else if (isArrivedAtPickup || isCompleted) {
      routeOrigin = _pickupLatLng;
      routeDestination = _dropoffLatLng;
    } else {
      // In transit / travelling to destination
      routeOrigin = startLatLng;
      routeDestination = _dropoffLatLng;
    }

    try {
      final List<LatLng> points = [];

      // Only request route if origin and destination are distinct
      if (routeOrigin.latitude != routeDestination.latitude ||
          routeOrigin.longitude != routeDestination.longitude) {
        final routeDetails = await RouteService.getRouteDetails(routeOrigin, routeDestination);
        points.addAll(routeDetails?.points ?? [routeOrigin, routeDestination]);
      } else {
        points.add(routeOrigin);
      }

      if (mounted) {
        setState(() {
          _routePoints = points;
          _isLoadingRoute = false;
        });

        if (shouldFit) {
          _fitMapBounds();
          _hasFittedCamera = true;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routePoints = [routeOrigin, routeDestination];
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _fitMapBounds() {
    final bool isHeadingToPickup =
        _currentStatus == 'กำลังไปรับ' ||
        _currentStatus == 'กำลังค้นหาคนขับ' ||
        _currentStatus == 'รอคนขับ';

    final bool isArrivedAtPickup =
        _currentStatus == 'ถึงจุดนัดหมาย' ||
        _currentStatus == 'ถึงจุดรับแล้ว';

    final pointsToFit = <LatLng>[];

    if (isHeadingToPickup) {
      // Focus strictly on Driver approaching Pickup Location
      if (_driverLatLng != null) {
        pointsToFit.add(_driverLatLng!);
      }
      pointsToFit.add(_pickupLatLng);
    } else if (isArrivedAtPickup) {
      // Focus on Pickup & Destination to prepare for journey
      pointsToFit.add(_pickupLatLng);
      pointsToFit.add(_dropoffLatLng);
    } else {
      // In transit or completed: focus on Driver/Pickup -> Destination
      if (_driverLatLng != null) {
        pointsToFit.add(_driverLatLng!);
      } else {
        pointsToFit.add(_pickupLatLng);
      }
      pointsToFit.add(_dropoffLatLng);
    }

    if (pointsToFit.isEmpty) return;

    // If single point or both points are identical, smoothly center the camera
    if (pointsToFit.length == 1 || (pointsToFit.length == 2 && pointsToFit[0] == pointsToFit[1])) {
      _mapController.move(pointsToFit.first, 15.5);
      return;
    }

    // Fit map bounds to show relevant focus points with responsive padding
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pointsToFit),
        padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 70.0),
      ),
    );
  }

  void _startStatusPolling() {
    // Poll immediately on start
    _checkStatus();

    // Setup periodic polling every 10 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
      AppSnackBar.showWarning(context, 'ไม่มีข้อมูลเบอร์โทรศัพท์สำหรับคนขับคนนี้');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ติดต่อ$role',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คนขับ: $name', style: const TextStyle(fontSize: 15, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            Text('เบอร์โทรศัพท์: $phoneNo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phoneNo));
                    AppSnackBar.showSuccess(context, 'คัดลอกเบอร์โทรศัพท์เรียบร้อยแล้ว');
                    Navigator.of(dialogContext).pop();
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('คัดลอก'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    AppSnackBar.showInfo(context, 'กำลังจำลองสายโทรไปที่ $phoneNo...');
                  },
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: const Text('โทรออก'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareTripLink() {
    final String leaderName = _leaderDriver != null && _leaderDriver!.fullName.isNotEmpty
        ? _leaderDriver!.fullName
        : 'ทีมคนขับ SafeSeat';

    final String carInfo = widget.carDetails.trim().isNotEmpty
        ? widget.carDetails
        : 'รถยนต์ของผู้ใช้บริการ';

    final String shareMessage =
        '🛡️ SafeSeat — แจ้งเตือนการเดินทาง (Live Tracking)\n\n'
        'ฉันกำลังเดินทางกลับอย่างปลอดภัยด้วยบริการคนขับแทน SafeSeat\n'
        'คุณสามารถนำรหัสทริปไปตรวจสอบสถานะและพิกัดการเดินทางสดได้:\n\n'
        '🔖 รหัสทริป: #${widget.requestId}\n'
        '🟢 สถานะปัจจุบัน: $_currentStatus\n'
        '🚘 ยานพาหนะ: $carInfo\n'
        '👤 ทีมคนขับ: $leaderName\n\n'
        '-----------------------------------\n'
        '🔍 วิธีติดตามการเดินทาง:\n'
        '1. ไปที่เว็บไซต์ SafeSeat\n'
        '2. เลือกเมนู "ติดตามการเดินทาง" (Live Trip Tracking)\n'
        '3. ระบุรหัสทริป: #${widget.requestId}\n'
        '-----------------------------------';

    // Auto-copy the message to the clipboard so the user can paste it anywhere
    Clipboard.setData(ClipboardData(text: shareMessage));
    AppSnackBar.showSuccess(context, 'คัดลอกข้อความติดตามการเดินทางเรียบร้อยแล้ว');

    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      shareMessage,
      subject: 'ติดตามการเดินทางของฉันบน SafeSeat (#${widget.requestId})',
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
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
      // Pickup Pin (ผับ / บาร์ / ร้านอาหาร) - Compact badge
      Marker(
        point: _pickupLatLng,
        width: 38,
        height: 38,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF97316), // ส้ม Amber/Orange สื่อถึง Nightlife/Pub & Restaurant
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.sports_bar_rounded, // หรือ Icons.nightlife_rounded / Icons.local_bar_rounded
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
      // Dropoff Pin (บ้าน / ที่พัก) - Compact badge
      Marker(
        point: _dropoffLatLng,
        width: 38,
        height: 38,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10B981), // สีเขียว Emerald สื่อถึงจุดหมายปลายทางที่ปลอดภัย
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.home_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    ];

    // Add Driver team pin if location exists (รถยนต์ของคนขับ)
    if (_driverLatLng != null) {
      markers.add(
        Marker(
          point: _driverLatLng!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: statusUI['color'] as Color, width: 2.5),
            ),
            child: Center(
              child: Icon(
                Icons.directions_car_filled_rounded,
                color: statusUI['color'] as Color,
                size: 22,
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
                initialCenter: _pickupLatLng,
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

          // 4. Draggable Bottom Info Panel (สามารถเลื่อนขึ้น-ลงเพื่อดูแผนที่ได้เต็มจอ)
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.15, 0.38, 0.85],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
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
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag Handle bar indicator
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),

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
                                      DriverAvatar(
                                        imageUrl: _leaderDriver!.resolvedImageUrl,
                                        fallbackName: '${_leaderDriver!.firstname} ${_leaderDriver!.lastname}',
                                        radius: 22,
                                        badgeText: 'D1',
                                        badgeColor: const Color(0xFF2563EB),
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
                                              'ผู้ขับรถของคุณ (${widget.carDetails})',
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
                                        DriverAvatar(
                                          imageUrl: _followerDriver!.resolvedImageUrl,
                                          fallbackName: '${_followerDriver!.firstname} ${_followerDriver!.lastname}',
                                          radius: 22,
                                          badgeText: 'D2',
                                          badgeColor: const Color(0xFF475569),
                                          defaultIcon: Icons.motorcycle,
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
                                               Text(
                                                 'รถขับตาม: ${_followerDriver!.vehicleSummary}',
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
              );
            },
          ),
        ],
      ),
    );
  }
}
