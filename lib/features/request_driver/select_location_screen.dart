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
  ConsumerState<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends ConsumerState<SelectLocationScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  LatLng _currentLatLng = const LatLng(18.8972, 99.0112); // Default Maejo
  String _resolvedAddress = 'กำลังโหลดตำแหน่ง...';
  bool _isGeocoding = false;
  Timer? _debounceTimer;
  Timer? _searchDebounceTimer;

  // Mock search results database for standard demonstration
  final List<Map<String, dynamic>> _mockPlaces = [
    {
      'name': 'แม่โจ้, หอพักพนม',
      'address': 'ถ.สหกรณ์ ต.หนองหาร อ.สันทราย เชียงใหม่',
      'latlng': const LatLng(18.8972, 99.0112)
    },
    {
      'name': 'มหาวิทยาลัยแม่โจ้',
      'address': 'ถ.เชียงใหม่-พร้าว ต.หนองหาร อ.สันทราย เชียงใหม่',
      'latlng': const LatLng(18.8950, 99.0150)
    },
    {
      'name': 'เซ็นทรัลเฟสติวัล เชียงใหม่',
      'address': 'ถ.ซุปเปอร์ไฮเวย์ ต.ฟ้าฮ่าม อ.เมือง เชียงใหม่',
      'latlng': const LatLng(18.8075, 99.0182)
    },
    {
      'name': 'ท่าอากาศยานเชียงใหม่ (CNX)',
      'address': 'ถ.มหิดล ต.สุเทพ อ.เมือง เชียงใหม่',
      'latlng': const LatLng(18.7670, 98.9632)
    },
    {
      'name': 'นิมมานเหมินท์ ซอย 9',
      'address': 'ต.สุเทพ อ.เมือง เชียงใหม่',
      'latlng': const LatLng(18.7989, 98.9681)
    },
    {
      'name': 'กาดหลวง (ตลาดวโรรส)',
      'address': 'ถ.วิชยานนท์ ต.ช้างม่อย อ.เมือง เชียงใหม่',
      'latlng': const LatLng(18.7903, 99.0003)
    },
  ];

  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    final reqState = ref.read(requestDriverControllerProvider);
    
    // Set initial coordinates based on current state
    if (widget.isPickup) {
      if (reqState.pickupLatLng != null) {
        _currentLatLng = reqState.pickupLatLng!;
        _resolvedAddress = reqState.pickupAddress ?? 'ตำแหน่งปักหมุด';
      } else {
        // Automatically fetch current location on screen open if not set yet
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _getCurrentLocation();
        });
      }
    } else {
      if (reqState.dropoffLatLng != null) {
        _currentLatLng = reqState.dropoffLatLng!;
        _resolvedAddress = reqState.dropoffAddress ?? 'ตำแหน่งปักหมุด';
      } else if (reqState.pickupLatLng != null) {
        // If drop-off not set yet, center around pickup location
        _currentLatLng = reqState.pickupLatLng!;
        _resolvedAddress = 'กำลังค้นหาตำแหน่งปลายทาง...';
      }
    }

    // Run initial reverse geocode if address not loaded
    if (_resolvedAddress == 'กำลังโหลดตำแหน่ง...' || _resolvedAddress == 'กำลังค้นหาตำแหน่งปลายทาง...') {
      _reverseGeocode(_currentLatLng);
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

  Future<void> _reverseGeocode(LatLng latLng) async {
    setState(() {
      _isGeocoding = true;
    });
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'SafeSeatMiniApp/1.0',
        'Accept-Language': 'th,en',
      });
      
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          final address = data['address'] as Map<String, dynamic>?;
          String shortName = '';
          if (address != null) {
            final road = address['road'];
            final suburb = address['suburb'] ?? address['neighbourhood'];
            final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['province'];
            
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
        }
      }
    } catch (e) {
      // keep previous or display coords
      if (mounted) {
        setState(() {
          _resolvedAddress = '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        AppSnackBar.showWarning(context, 'กรุณาเปิดบริการระบุตำแหน่ง (GPS)');
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          AppSnackBar.showWarning(context, 'สิทธิ์การเข้าถึงตำแหน่งถูกปฏิเสธ');
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'สิทธิ์การระบุตำแหน่งถูกปฏิเสธอย่างถาวร กรุณาเปิดสิทธิ์ในการตั้งค่าของอุปกรณ์',
        );
      }
      return;
    } 

    if (!mounted) return;
    setState(() {
      _isGeocoding = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      final latLng = LatLng(position.latitude, position.longitude);
      
      if (!mounted) return;
      setState(() {
        _currentLatLng = latLng;
      });

      _mapController.move(latLng, 16.0);
      await _reverseGeocode(latLng);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'ไม่สามารถดึงตำแหน่งปัจจุบันได้: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    _currentLatLng = camera.center;
    if (hasGesture) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 650), () {
        _reverseGeocode(_currentLatLng);
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseUrl}/api/user/location/search?q=${Uri.encodeComponent(query)}&lat=${_currentLatLng.latitude}&lng=${_currentLatLng.longitude}'
      );

      final response = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'] ?? [];
        
        setState(() {
          _searchResults = results.map<Map<String, dynamic>>((item) => {
            'name': item['name'] ?? '',
            'address': item['address'] ?? '',
            'latlng': LatLng(
              (item['latitude'] as num).toDouble(),
              (item['longitude'] as num).toDouble(),
            ),
          }).toList();
          _showSearchResults = true;
        });
      }
    } catch (e) {
      // Fallback to mock search on error so the app continues working gracefully
      final filtered = _mockPlaces.where((place) {
        final name = place['name'].toString().toLowerCase();
        final address = place['address'].toString().toLowerCase();
        return name.contains(query.toLowerCase()) || address.contains(query.toLowerCase());
      }).toList();

      if (!mounted) return;
      setState(() {
        _searchResults = filtered;
        _showSearchResults = true;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> place) {
    final name = place['name'] as String;
    final latLng = place['latlng'] as LatLng;

    setState(() {
      _currentLatLng = latLng;
      _resolvedAddress = name;
      _showSearchResults = false;
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });

    _mapController.move(latLng, 16.0);
  }

  Future<void> _selectSavedHome(String homeAddress, LatLng? homeLatLng) async {
    setState(() {
      _resolvedAddress = homeAddress;
      _showSearchResults = false;
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });

    // If exact pinned LatLng is available, use it directly!
    if (homeLatLng != null) {
      setState(() {
        _currentLatLng = homeLatLng;
        _isGeocoding = false;
      });
      _mapController.move(homeLatLng, 16.0);
      return;
    }

    setState(() {
      _isGeocoding = true;
    });

    try {
      final searchUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(homeAddress)}&format=json&limit=1',
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
          if (mounted) {
            setState(() {
              _currentLatLng = latLng;
              _isGeocoding = false;
            });
            _mapController.move(latLng, 16.0);
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isGeocoding = false;
      });
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
              margin: const EdgeInsets.only(bottom: 35), // Offset for pin point to match center
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
                  // The actual Pin Icon
                  widget.isPickingForProfile
                      ? const Icon(
                          Icons.home,
                          color: Color(0xFF0044C9),
                          size: 45,
                        )
                      : (widget.isPickup
                          ? const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 45,
                            )
                          : const Icon(
                              Icons.location_on,
                              color: Color(0xFF10B981),
                              size: 45,
                            )),
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
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        // Indicator pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
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
                                  ? const Color(0xFF0044C9)
                                  : (widget.isPickup ? Colors.red : Colors.blueGrey[800]),
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
                        IconButton(
                          icon: const Icon(Icons.mic, color: Colors.grey),
                          onPressed: () {},
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
                            if (user?.homeDisplayName != null && user!.homeDisplayName!.trim().isNotEmpty) ...[
                              ActionChip(
                                avatar: const Icon(Icons.home, color: AppTheme.primaryColor, size: 16),
                                label: Text(
                                  'บ้าน: ${user.homeDisplayName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: Colors.black26,
                                onPressed: () => _selectSavedHome(user.homeDisplayName!, user.homeLatLng),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ActionChip(
                              avatar: const Icon(Icons.my_location, color: Colors.red, size: 16),
                              label: const Text(
                                'ตำแหน่งปัจจุบัน',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
                  
                  // Search Results List
                  if (_showSearchResults && _searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 250),
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
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[100],
                              child: Icon(
                                widget.isPickup ? Icons.location_on : Icons.flag,
                                color: widget.isPickup ? Colors.red : Colors.grey,
                              ),
                            ),
                            title: Text(
                              place['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                              ? const Color(0xFF0044C9).withValues(alpha: 0.1)
                              : (widget.isPickup 
                                  ? Colors.red.withValues(alpha: 0.1) 
                                  : Colors.blueGrey.withValues(alpha: 0.1)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isPickingForProfile
                              ? Icons.home
                              : (widget.isPickup ? Icons.location_on : Icons.flag),
                          color: widget.isPickingForProfile
                              ? const Color(0xFF0044C9)
                              : (widget.isPickup ? Colors.red : const Color(0xFF1E293B)),
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
                                    child: CircularProgressIndicator(strokeWidth: 2),
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
                      onPressed: _isGeocoding
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
                                  ref.read(requestDriverControllerProvider.notifier)
                                      .setPickup(_resolvedAddress, _currentLatLng);
                                } else {
                                  ref.read(requestDriverControllerProvider.notifier)
                                      .setDropoff(_resolvedAddress, _currentLatLng);
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
                      child: const Text(
                        'เสร็จสิ้น',
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

          // 5. Floating Action Buttons (Zoom and My Location)
          Positioned(
            right: 16,
            bottom: 240, // Floating above the bottom card
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In
                FloatingActionButton.small(
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
                FloatingActionButton.small(
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
