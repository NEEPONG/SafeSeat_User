import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:safeseat_mini/features/request_driver/controllers/request_driver_controller.dart';
import 'package:safeseat_mini/core/constants/api_constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';

import 'package:safeseat_mini/core/controllers/user_controller.dart';

class SelectLocationScreen extends ConsumerStatefulWidget {
  final bool isPickup;
  final bool isPickingForProfile;

  const SelectLocationScreen({
    super.key,
    required this.isPickup,
    this.isPickingForProfile = false,
  });

  @override
  ConsumerState<SelectLocationScreen> createState() =>
      _SelectLocationScreenState();
}

class _SelectLocationScreenState extends ConsumerState<SelectLocationScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Map center only. This point is never a confirmed pickup or drop-off.
  LatLng _currentLatLng = const LatLng(18.7883, 98.9853);
  String _resolvedAddress = 'ค้นหาสถานที่หรือเลื่อนแผนที่เพื่อปักหมุด';
  bool _isGeocoding = false;
  bool _hasSelectedLocation = false;
  int _locationSelectionId = 0;
  Timer? _debounceTimer;
  Timer? _searchDebounceTimer;

  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearching = false;
  bool _searchFailed = false;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    final reqState = ref.read(requestDriverControllerProvider);

    if (widget.isPickingForProfile) {
      final user = ref.read(userProvider);
      if (user?.homeLatLng != null) {
        _currentLatLng = user!.homeLatLng!;
        _resolvedAddress = user.homeDisplayName ?? 'ที่อยู่บ้านที่บันทึกไว้';
        _hasSelectedLocation = true;
      }
    } else if (widget.isPickup) {
      if (reqState.pickupLatLng != null) {
        _currentLatLng = reqState.pickupLatLng!;
        _resolvedAddress = reqState.pickupAddress ?? 'ตำแหน่งปักหมุด';
        _hasSelectedLocation = true;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _getCurrentLocation();
        });
      }
    } else {
      if (reqState.dropoffLatLng != null) {
        _currentLatLng = reqState.dropoffLatLng!;
        _resolvedAddress = reqState.dropoffAddress ?? 'ตำแหน่งปักหมุด';
        _hasSelectedLocation = true;
      } else if (reqState.pickupLatLng != null) {
        // Center the map near pickup, but do not select it as the destination.
        _currentLatLng = reqState.pickupLatLng!;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng latLng, int selectionId) async {
    if (!mounted || selectionId != _locationSelectionId) return;
    setState(() {
      _isGeocoding = true;
    });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'SafeSeatMiniApp/1.0',
              'Accept-Language': 'th,en',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted || selectionId != _locationSelectionId) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          final address = data['address'] as Map<String, dynamic>?;
          String shortName = '';
          if (address != null) {
            final road = address['road'];
            final suburb = address['suburb'] ?? address['neighbourhood'];
            final city =
                address['city'] ??
                address['town'] ??
                address['municipality'] ??
                address['province'];

            if (road != null) {
              shortName += '$road';
            }
            if (suburb != null) {
              if (shortName.isNotEmpty) shortName += ', ';
              shortName += '$suburb';
            }
            if (city != null) {
              if (shortName.isNotEmpty) shortName += ', ';
              shortName += '$city';
            }
          }

          if (shortName.isEmpty) {
            final parts = displayName.split(',');
            shortName = parts.take(2).join(', ').trim();
          }

          setState(() {
            _resolvedAddress = shortName;
          });
          return;
        }
      }
      setState(() {
        _resolvedAddress =
            '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      if (!mounted || selectionId != _locationSelectionId) return;
      setState(() {
        _resolvedAddress =
            '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
      });
    } finally {
      if (mounted && selectionId == _locationSelectionId) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    final selectionIdBeforeRequest = _locationSelectionId;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        AppSnackBar.showWarning(context, 'โปรดเปิดบริการระบุตำแหน่งในอุปกรณ์');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          AppSnackBar.showWarning(context, 'โปรดอนุญาตให้แอปเข้าถึงตำแหน่ง');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        AppSnackBar.showError(
          context,
          'โปรดเปิดสิทธิ์เข้าถึงตำแหน่งในการตั้งค่าอุปกรณ์',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      if (!mounted || selectionIdBeforeRequest != _locationSelectionId) return;
      _debounceTimer?.cancel();
      _mapController.move(latLng, 16.0);
      final selectionId = ++_locationSelectionId;
      setState(() {
        _currentLatLng = latLng;
        _resolvedAddress = 'กำลังค้นหาที่อยู่...';
        _hasSelectedLocation = true;
        _isGeocoding = true;
      });
      await _reverseGeocode(latLng, selectionId);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'ดึงตำแหน่งปัจจุบันไม่ได้ โปรดลองอีกครั้ง',
        );
      }
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    _currentLatLng = camera.center;
    if (hasGesture) {
      final selectionId = ++_locationSelectionId;
      if (!_hasSelectedLocation ||
          !_isGeocoding ||
          _resolvedAddress != 'กำลังค้นหาที่อยู่...') {
        setState(() {
          _hasSelectedLocation = true;
          _isGeocoding = true;
          _resolvedAddress = 'กำลังค้นหาที่อยู่...';
        });
      }
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 650), () {
        _reverseGeocode(camera.center, selectionId);
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    final searchQuery = query.trim();
    final requestId = ++_searchRequestId;
    if (searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
        _searchFailed = false;
      });
      return;
    }

    setState(() {
      _searchResults = [];
      _showSearchResults = true;
      _isSearching = true;
      _searchFailed = false;
    });
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(searchQuery, requestId);
    });
  }

  void _retrySearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    _searchDebounceTimer?.cancel();
    final requestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _searchFailed = false;
      _searchResults = [];
    });
    _performSearch(query, requestId);
  }

  void _useMapPin() {
    _searchDebounceTimer?.cancel();
    ++_searchRequestId;
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
      _showSearchResults = false;
      _isSearching = false;
      _searchFailed = false;
    });
  }

  Future<void> _performSearch(String query, int requestId) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseUrl}/api/user/location/search?q=${Uri.encodeComponent(query)}&lat=${_currentLatLng.latitude}&lng=${_currentLatLng.longitude}',
      );

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const FormatException('Location search unavailable');
      }
      final data = jsonDecode(response.body);
      final List results = data['results'] ?? [];
      final places = results
          .map<Map<String, dynamic>>(
            (item) => {
              'name': item['name'] ?? '',
              'address': item['address'] ?? '',
              'latlng': LatLng(
                (item['latitude'] as num).toDouble(),
                (item['longitude'] as num).toDouble(),
              ),
            },
          )
          .toList();
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = places;
        _isSearching = false;
        _searchFailed = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchFailed = true;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> place) {
    final name = place['name'] as String;
    final latLng = place['latlng'] as LatLng;

    _searchDebounceTimer?.cancel();
    _debounceTimer?.cancel();
    ++_searchRequestId;
    ++_locationSelectionId;
    setState(() {
      _currentLatLng = latLng;
      _resolvedAddress = name;
      _hasSelectedLocation = true;
      _isGeocoding = false;
      _showSearchResults = false;
      _searchResults = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });

    _mapController.move(latLng, 16.0);
  }

  Future<void> _selectSavedHome(String homeAddress, LatLng? homeLatLng) async {
    _searchDebounceTimer?.cancel();
    _debounceTimer?.cancel();
    ++_searchRequestId;
    final selectionId = ++_locationSelectionId;
    setState(() {
      _resolvedAddress = homeLatLng == null
          ? 'กำลังค้นหาที่อยู่บ้าน...'
          : homeAddress;
      _hasSelectedLocation = homeLatLng != null;
      _isGeocoding = homeLatLng == null;
      _showSearchResults = false;
      _searchResults = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });

    // If exact pinned LatLng is available, use it directly!
    if (homeLatLng != null) {
      setState(() {
        _currentLatLng = homeLatLng;
      });
      _mapController.move(homeLatLng, 16.0);
      return;
    }

    try {
      final searchUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(homeAddress)}&format=json&limit=1',
      );
      final response = await http
          .get(
            searchUrl,
            headers: {
              'User-Agent': 'SafeSeatMiniApp/1.0',
              'Accept-Language': 'th,en',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          final latLng = LatLng(lat, lon);
          if (mounted && selectionId == _locationSelectionId) {
            setState(() {
              _currentLatLng = latLng;
              _resolvedAddress = homeAddress;
              _hasSelectedLocation = true;
              _isGeocoding = false;
            });
            _mapController.move(latLng, 16.0);
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted && selectionId == _locationSelectionId) {
      setState(() {
        _resolvedAddress = 'ค้นหาสถานที่หรือเลื่อนแผนที่เพื่อปักหมุด';
        _isGeocoding = false;
      });
      AppSnackBar.showWarning(
        context,
        'ค้นหาพิกัดที่อยู่บ้านไม่ได้ โปรดปักหมุดเอง',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final titleText = widget.isPickingForProfile
        ? 'เลือกตำแหน่งที่อยู่บ้าน'
        : (widget.isPickup ? 'จุดรับ' : 'จุดส่ง');
    final themeColor = AppTheme.primaryColor;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Widget
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLatLng,
              initialZoom: 15.5,
              maxZoom: 18.0,
              minZoom: 5.0,
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safeseat.mini',
              ),
            ],
          ),

          // 2. Fixed Centered Pin
          Center(
            child: Container(
              margin: const EdgeInsets.only(
                bottom: 35,
              ), // Offset for pin point to match center
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pin shadow
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Icon(
                    widget.isPickingForProfile ? Icons.home : Icons.location_on,
                    color: !_hasSelectedLocation
                        ? Colors.grey
                        : widget.isPickingForProfile
                        ? AppTheme.primaryColor
                        : widget.isPickup
                        ? AppTheme.pickupColor
                        : AppTheme.dropoffColor,
                    size: 45,
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Search Card & Quick Suggestions
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        // Indicator pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (widget.isPickingForProfile
                                        ? AppTheme.primaryColor
                                        : widget.isPickup
                                        ? AppTheme.pickupColor
                                        : AppTheme.dropoffColor)
                                    .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            widget.isPickingForProfile
                                ? 'ที่อยู่บ้าน'
                                : (widget.isPickup ? 'จุดรับ' : 'จุดส่ง'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.isPickingForProfile
                                  ? AppTheme.primaryColor
                                  : (widget.isPickup
                                        ? AppTheme.pickupColor
                                        : AppTheme.dropoffColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: const InputDecoration(
                              hintText: 'กรอกที่อยู่เพื่อค้นหา',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                      ],
                    ),
                  ),

                  // Quick Suggestions Chips (when search is empty)
                  if (!_showSearchResults && !widget.isPickingForProfile)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (user?.homeDisplayName != null &&
                                user!.homeDisplayName!.trim().isNotEmpty) ...[
                              ActionChip(
                                avatar: const Icon(
                                  Icons.home,
                                  color: AppTheme.primaryColor,
                                  size: 16,
                                ),
                                label: Text(
                                  'บ้าน: ${user.homeDisplayName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: Colors.black26,
                                onPressed: () => _selectSavedHome(
                                  user.homeDisplayName!,
                                  user.homeLatLng,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ActionChip(
                              avatar: const Icon(
                                Icons.my_location,
                                color: AppTheme.pickupColor,
                                size: 16,
                              ),
                              label: const Text(
                                'ตำแหน่งปัจจุบัน',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: Colors.white,
                              elevation: 3,
                              shadowColor: Colors.black26,
                              onPressed: _getCurrentLocation,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Search results and search status
                  if (_showSearchResults)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: BoxConstraints(
                        maxHeight:
                            (MediaQuery.sizeOf(context).height -
                                MediaQuery.viewInsetsOf(context).bottom) *
                            0.28,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('กำลังค้นหาสถานที่...'),
                                ],
                              ),
                            )
                          : _searchResults.isEmpty
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _searchFailed
                                        ? 'ค้นหาสถานที่ไม่ได้ โปรดลองอีกครั้ง'
                                        : 'ไม่พบสถานที่ ลองใช้คำค้นอื่น',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('หรือเลื่อนแผนที่เพื่อปักหมุดเอง'),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (_searchFailed)
                                        TextButton.icon(
                                          onPressed: _retrySearch,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('ลองอีกครั้ง'),
                                        ),
                                      TextButton.icon(
                                        onPressed: _useMapPin,
                                        icon: const Icon(Icons.place_outlined),
                                        label: const Text('ปักหมุดบนแผนที่'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final place = _searchResults[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey[100],
                                    child: Icon(
                                      widget.isPickup
                                          ? Icons.location_on
                                          : Icons.flag,
                                      color: widget.isPickingForProfile
                                          ? AppTheme.primaryColor
                                          : widget.isPickup
                                          ? AppTheme.pickupColor
                                          : AppTheme.dropoffColor,
                                    ),
                                  ),
                                  title: Text(
                                    place['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    place['address'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectSearchResult(place),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Bottom Confirmation Panel
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.44,
                ),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
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
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Location Address Box
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: widget.isPickingForProfile
                                    ? AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      )
                                    : (widget.isPickup
                                          ? AppTheme.pickupColor.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppTheme.dropoffColor.withValues(
                                              alpha: 0.1,
                                            )),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.isPickingForProfile
                                    ? Icons.home
                                    : (widget.isPickup
                                          ? Icons.location_on
                                          : Icons.flag),
                                color: widget.isPickingForProfile
                                    ? AppTheme.primaryColor
                                    : (widget.isPickup
                                          ? AppTheme.pickupColor
                                          : AppTheme.dropoffColor),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _isGeocoding
                                  ? const Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'กำลังดึงข้อมูลตำแหน่ง...',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _resolvedAddress,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF334155),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Confirm Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                !_hasSelectedLocation ||
                                    _isGeocoding ||
                                    _showSearchResults
                                ? null
                                : () {
                                    if (widget.isPickingForProfile) {
                                      Navigator.of(context).pop({
                                        'address': _resolvedAddress,
                                        'latLng': _currentLatLng,
                                      });
                                    } else {
                                      // Save state to provider
                                      if (widget.isPickup) {
                                        ref
                                            .read(
                                              requestDriverControllerProvider
                                                  .notifier,
                                            )
                                            .setPickup(
                                              _resolvedAddress,
                                              _currentLatLng,
                                            );
                                      } else {
                                        ref
                                            .read(
                                              requestDriverControllerProvider
                                                  .notifier,
                                            )
                                            .setDropoff(
                                              _resolvedAddress,
                                              _currentLatLng,
                                            );
                                      }
                                      Navigator.of(context).pop();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              widget.isPickingForProfile
                                  ? 'บันทึกที่อยู่บ้าน'
                                  : widget.isPickup
                                  ? 'ยืนยันจุดรับ'
                                  : 'ยืนยันจุดส่ง',
                              style: const TextStyle(
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
              ),
            ),

          // 5. Floating Action Buttons (Zoom and My Location)
          if (MediaQuery.viewInsetsOf(context).bottom == 0 &&
              !_showSearchResults &&
              MediaQuery.sizeOf(context).height > 560)
            Positioned(
              right: 16,
              bottom: MediaQuery.sizeOf(context).height * 0.44 + 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom In
                  FloatingActionButton(
                    heroTag: 'zoom_in_btn',
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_currentLatLng, currentZoom + 1);
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E293B),
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  // Zoom Out
                  FloatingActionButton(
                    heroTag: 'zoom_out_btn',
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_currentLatLng, currentZoom - 1);
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E293B),
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(height: 12),
                  // My Location
                  FloatingActionButton(
                    heroTag: 'my_location_btn',
                    onPressed: _getCurrentLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E293B),
                    child: const Icon(Icons.my_location),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
