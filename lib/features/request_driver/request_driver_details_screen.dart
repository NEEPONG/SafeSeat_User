import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:safeseat_mini/features/request_driver/controllers/request_driver_controller.dart';
import 'package:safeseat_mini/features/profile/controllers/profile_controller.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/data/models/car_model.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/services/route_service.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/core/utils/validators.dart';
import 'package:safeseat_mini/features/request_driver/payment_method_screen.dart';
import 'package:safeseat_mini/features/request_driver/waiting_driver_screen.dart';

class RequestDriverDetailsScreen extends ConsumerStatefulWidget {
  const RequestDriverDetailsScreen({super.key});

  @override
  ConsumerState<RequestDriverDetailsScreen> createState() =>
      _RequestDriverDetailsScreenState();
}

class _RequestDriverDetailsScreenState
    extends ConsumerState<RequestDriverDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  CarModel? _selectedCar;
  bool _ladyMode = false;
  final TextEditingController _remarksController = TextEditingController();
  String _paymentMethod = 'เงินสด';
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  double _estimatedPrice = 300.0;
  double _distanceInKm = 0.0;
  bool _isSubmitting = false;
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoute();
    });
  }

  Future<void> _loadRoute() async {
    final reqState = ref.read(requestDriverControllerProvider);
    final pickup = reqState.pickupLatLng;
    final dropoff = reqState.dropoffLatLng;

    if (pickup == null || dropoff == null) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    final routeDetails = await RouteService.getRouteDetails(pickup, dropoff);

    if (mounted) {
      double calculatedPrice = 300.0;
      double distanceKm = 0.0;
      List<LatLng> points = [pickup, dropoff];

      if (routeDetails != null) {
        points = routeDetails.points.isNotEmpty
            ? routeDetails.points
            : [pickup, dropoff];
        distanceKm = routeDetails.distance / 1000.0;
        calculatedPrice = 300.0 + (distanceKm * 10.0);
      } else {
        // Fallback using straight-line distance if API fails
        final distanceMeters =
            const Distance().as(LengthUnit.Meter, pickup, dropoff);
        distanceKm = distanceMeters / 1000.0;
        calculatedPrice = 300.0 + (distanceKm * 10.0);
      }

      setState(() {
        _routePoints = points;
        _estimatedPrice = calculatedPrice;
        _distanceInKm = distanceKm;
        _isLoadingRoute = false;
      });

      _fitMapBounds();
    }
  }

  void _fitMapBounds() {
    final reqState = ref.read(requestDriverControllerProvider);
    final pickup = reqState.pickupLatLng;
    final dropoff = reqState.dropoffLatLng;

    if (pickup != null && dropoff != null) {
      if (pickup.latitude != dropoff.latitude ||
          pickup.longitude != dropoff.longitude) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(pickup, dropoff),
            padding: const EdgeInsets.only(
              left: 50.0,
              right: 50.0,
              top: 80.0,
              bottom: 280.0,
            ),
          ),
        );
      } else {
        _mapController.move(pickup, 15.0);
      }
    } else if (pickup != null) {
      _mapController.move(pickup, 15.0);
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom < 18.0) {
      _mapController.move(_mapController.camera.center, currentZoom + 1);
    }
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom > 5.0) {
      _mapController.move(_mapController.camera.center, currentZoom - 1);
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _showCarSelectionSheet(List<CarModel> cars) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'เลือกยานพาหนะของคุณ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              if (cars.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'คุณยังไม่มีรถที่ลงทะเบียน\nกรุณาเพิ่มข้อมูลรถในหน้าโปรไฟล์',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cars.length,
                    itemBuilder: (context, index) {
                      final car = cars[index];
                      final isSelected =
                          _selectedCar?.userCarId == car.userCarId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.directions_car,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey,
                          ),
                        ),
                        title: Text(
                          '${car.carBrand} ${car.carModel}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${car.carColor} • ${car.carPlate}'),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryColor,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedCar = car;
                          });
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showInsufficientBalanceDialog(num balance) {
    AppDialog.showWarning(
      context: context,
      title: 'ยอดเงินไม่เพียงพอ',
      message:
          'ยอดเงินคงเหลือใน SafeSeat Wallet (฿${balance.toStringAsFixed(2)}) ไม่เพียงพอสำหรับค่าบริการครั้งนี้ (฿${_estimatedPrice.toStringAsFixed(0)})\n\nคุณต้องการเปลี่ยนวิธีการชำระเงินเป็นเงินสดหรือไม่?',
      primaryButtonText: 'ใช้เงินสดแทน',
      secondaryButtonText: 'ยกเลิก',
      onPrimaryPressed: () {
        setState(() {
          _paymentMethod = 'เงินสด';
        });
        AppSnackBar.showSuccess(
          context,
          'เปลี่ยนช่องทางการชำระเงินเป็น เงินสด เรียบร้อยแล้ว',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reqState = ref.watch(requestDriverControllerProvider);
    final user = ref.watch(userProvider);
    final phoneNo = user?.phoneNo ?? '';

    // Load user's cars
    final carListAsync = ref.watch(userCarListProvider(phoneNo));

    // Auto-select first car as default once data loaded
    carListAsync.whenData((cars) {
      if (_selectedCar == null && cars.isNotEmpty) {
        // Run after build pass to avoid setState during build compile warnings
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedCar = cars.first;
            });
          }
        });
      }
    });

    // Default coordinates
    final pickupLatLng =
        reqState.pickupLatLng ?? const LatLng(18.8972, 99.0112);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Full Interactive Background Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pickupLatLng,
                initialZoom: 15.0,
                maxZoom: 18.5,
                minZoom: 5.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safeseat.mini',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: AppTheme.primaryColor,
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (reqState.pickupLatLng != null)
                      Marker(
                        point: reqState.pickupLatLng!,
                        width: 100,
                        height: 80,
                        child: Column(
                          children: [
                            // Custom label bubble
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'รับที่นี่',
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
                    if (reqState.dropoffLatLng != null)
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
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'ส่งที่นี่',
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
                  ],
                ),
              ],
            ),
          ),

          // Route Loading Progress Bar
          if (_isLoadingRoute)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),

          // 2. Floating Top-Left Back Button
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
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF1E293B),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating Map Action Controls (Recenter & Zoom buttons)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recenter / Fit bounds button
                FloatingActionButton.small(
                  heroTag: 'recenter_btn_details',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 4,
                  onPressed: _fitMapBounds,
                  shape: const CircleBorder(),
                  tooltip: 'ปรับมุมมองแผนที่',
                  child: const Icon(Icons.my_location, size: 20),
                ),
                const SizedBox(height: 10),
                // Zoom in button
                FloatingActionButton.small(
                  heroTag: 'zoom_in_btn_details',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 4,
                  onPressed: _zoomIn,
                  shape: const CircleBorder(),
                  tooltip: 'ซูมเข้า',
                  child: const Icon(Icons.add, size: 22),
                ),
                const SizedBox(height: 10),
                // Zoom out button
                FloatingActionButton.small(
                  heroTag: 'zoom_out_btn_details',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 4,
                  onPressed: _zoomOut,
                  shape: const CircleBorder(),
                  tooltip: 'ซูมออก',
                  child: const Icon(Icons.remove, size: 22),
                ),
              ],
            ),
          ),

          // 4. Draggable Scrollable Sheet (แถบรายละเอียดเลื่อนขึ้น-ลงได้)
          DraggableScrollableSheet(
            initialChildSize: 0.52,
            minChildSize: 0.20,
            maxChildSize: 0.90,
            snap: true,
            snapSizes: const [0.20, 0.52, 0.90],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          // Grab Handle Bar
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Route Summary Card (จุดรับ - จุดส่ง & ระยะทาง)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        reqState.pickupAddress ??
                                            'จุดรับผู้โดยสาร',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_distanceInKm > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_distanceInKm.toStringAsFixed(1)} กม.',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      height: 12,
                                      child: VerticalDivider(
                                        thickness: 1.5,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        reqState.dropoffAddress ??
                                            'จุดส่งปลายทาง',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Vehicle Selection Section
                          const Text(
                            'กรุณาเลือกยานพาหนะของท่าน',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 10),

                          carListAsync.when(
                            loading: () => Container(
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            error: (error, stack) => Container(
                              height: 68,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'ไม่สามารถโหลดข้อมูลยานพาหนะได้',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                            data: (cars) {
                              final displayedText = _selectedCar != null
                                  ? '${_selectedCar!.carBrand} ${_selectedCar!.carModel} (${_selectedCar!.carPlate})'
                                  : 'กรุณาเลือกยานพาหนะ';
                              final displayedType =
                                  _selectedCar?.carTypeName ??
                                      'ไม่มีประเภทระบุ';

                              return InkWell(
                                onTap: () => _showCarSelectionSheet(cars),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.directions_car,
                                          color: AppTheme.primaryColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayedText,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E293B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              displayedType,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          // Lady Mode Section
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF2F8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.female,
                                    color: Color(0xFFEC4899),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Text(
                                        'เลดี้โหมด',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'FREE',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _ladyMode,
                                  activeThumbColor: const Color(0xFFEC4899),
                                  activeTrackColor: const Color(0xFFEC4899)
                                      .withValues(alpha: 0.3),
                                  onChanged: (val) {
                                    setState(() {
                                      _ladyMode = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Remarks Section
                          const Text(
                            'หมายเหตุ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _remarksController,
                            maxLines: 2,
                            validator: AppValidators.validateNote,
                            decoration: InputDecoration(
                              hintText:
                                  'ระบุหมายเหตุ เช่น จุดสังเกต หรือสิ่งที่ต้องการแจ้งคนขับ',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                              fillColor: Colors.white,
                              filled: true,
                              contentPadding: const EdgeInsets.all(14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(16)),
                                borderSide: BorderSide(
                                  color: AppTheme.primaryColor,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                              focusedErrorBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(16)),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Payment Method Section
                          const Text(
                            'การชำระเงิน',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final selected =
                                  await Navigator.of(context).push<String>(
                                MaterialPageRoute(
                                  builder: (context) => PaymentMethodScreen(
                                    initialMethod: _paymentMethod,
                                  ),
                                ),
                              );
                              if (selected != null) {
                                setState(() {
                                  _paymentMethod = selected;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _paymentMethod.startsWith('เงินสด')
                                        ? Icons.payments
                                        : Icons.account_balance_wallet,
                                    color: const Color(0xFF64748B),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _paymentMethod,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Estimated Price & Call Driver Action Card
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ยอดรวมโดยประมาณ',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        if (_distanceInKm > 0)
                                          Text(
                                            'ระยะทาง ${_distanceInKm.toStringAsFixed(1)} กม.',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      '฿${_estimatedPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Call Driver Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () async {
                                            if (!_formKey.currentState!.validate() ||
                                                _selectedCar == null ||
                                                reqState.pickupLatLng == null ||
                                                reqState.dropoffLatLng == null) {
                                              if (_selectedCar == null) {
                                                AppSnackBar.showWarning(
                                                  context,
                                                  'กรุณาเลือกยานพาหนะที่จะให้คนขับขับก่อนทำรายการ',
                                                );
                                              } else {
                                                AppSnackBar.showWarning(
                                                  context,
                                                  'กรุณากรอกข้อมูลและเลือกจุดรับ-ส่งให้ครบถ้วน',
                                                );
                                              }
                                              return;
                                            }

                                            final user =
                                                ref.read(userProvider);
                                            final balance =
                                                user?.walletBalance ?? 0.0;
                                            final isWallet = !_paymentMethod
                                                .startsWith('เงินสด');

                                            if (isWallet &&
                                                balance < _estimatedPrice) {
                                              _showInsufficientBalanceDialog(
                                                balance,
                                              );
                                              return;
                                            }

                                            setState(() {
                                              _isSubmitting = true;
                                            });

                                            try {
                                              final requestId = await ref
                                                  .read(
                                                    requestDriverControllerProvider
                                                        .notifier,
                                                  )
                                                  .createRequest(
                                                    dropoffLatitude: reqState
                                                        .dropoffLatLng!
                                                        .latitude,
                                                    dropoffLongitude: reqState
                                                        .dropoffLatLng!
                                                        .longitude,
                                                    isLadyMode: _ladyMode,
                                                    note: _remarksController
                                                        .text
                                                        .trim(),
                                                    paymentMethod:
                                                        _paymentMethod,
                                                    pickupLatitude: reqState
                                                        .pickupLatLng!.latitude,
                                                    pickupLongitude: reqState
                                                        .pickupLatLng!
                                                        .longitude,
                                                    reqDistance: _distanceInKm,
                                                    requestFee: _estimatedPrice,
                                                    userId: phoneNo,
                                                    userCarId: _selectedCar!
                                                        .userCarId,
                                                  );

                                              if (requestId != null) {
                                                // Refresh user profile to immediately reflect deducted wallet balance
                                                ref
                                                    .read(
                                                      profileControllerProvider
                                                          .notifier,
                                                    )
                                                    .getUserProfile(phoneNo);

                                                if (context.mounted) {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          WaitingDriverScreen(
                                                        requestId: requestId,
                                                        pickupAddress: reqState
                                                                .pickupAddress ??
                                                            'ตำแหน่งปัจจุบัน',
                                                        dropoffAddress: reqState
                                                                .dropoffAddress ??
                                                            'ปลายทาง',
                                                        carDetails:
                                                            '${_selectedCar!.carBrand} ${_selectedCar!.carModel}',
                                                        price: _estimatedPrice,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                if (context.mounted) {
                                                  AppSnackBar.showError(
                                                    context,
                                                    'ไม่สามารถสร้างคำขอได้ กรุณาลองใหม่อีกครั้ง',
                                                  );
                                                }
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                final errorMsg = e.toString().replaceFirst('Exception: ', '');
                                                  AppSnackBar.showError(context, errorMsg);
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() {
                                                  _isSubmitting = false;
                                                });
                                              }
                                            }
                                          },
                                    icon: _isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.bolt,
                                            color: Colors.white,
                                          ),
                                    label: Text(
                                      _isSubmitting
                                          ? 'กำลังส่งคำขอ...'
                                          : 'เรียกคนขับ',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                          BorderRadius.circular(28),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
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
