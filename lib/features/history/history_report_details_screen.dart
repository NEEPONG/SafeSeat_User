import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safeseat_mini/core/widgets/driver_avatar.dart';
import 'package:safeseat_mini/data/models/driver_report_model.dart';

class ReportedDriverInfo {
  final String username;
  final String fullname;
  final String role; // 'คนขับหลัก' | 'ผู้ช่วยผู้ขับรถ' | 'ผู้ขับรถ'
  final String? phoneNo;
  final String? licensePlate;
  final String? imageUrl;
  final String rating;

  ReportedDriverInfo({
    required this.username,
    required this.fullname,
    required this.role,
    this.phoneNo,
    this.licensePlate,
    this.imageUrl,
    required this.rating,
  });
}

class HistoryReportDetailsScreen extends StatefulWidget {
  final DriverReportModel report;

  const HistoryReportDetailsScreen({super.key, required this.report});

  @override
  State<HistoryReportDetailsScreen> createState() => _HistoryReportDetailsScreenState();
}

class _HistoryReportDetailsScreenState extends State<HistoryReportDetailsScreen> {
  bool _isLoading = true;
  List<ReportedDriverInfo> _reportedDrivers = [];

  @override
  void initState() {
    super.initState();
    _fetchReportedDrivers();
  }

  /// Extracts driver usernames/IDs from reportDetail string (e.g. "[ID: d1,d2] details")
  List<String> _extractReportedDriverIds(String? detail) {
    if (detail == null || detail.isEmpty) return [];

    final idRegex = RegExp(r'\[ID:\s*([^\]]+)\]', caseSensitive: false);
    final match = idRegex.firstMatch(detail);
    if (match != null && match.group(1) != null) {
      return match.group(1)!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Removes [ID: ...] or [เป้าหมาย: ...] prefixes to show clean description
  String _cleanReportDetail(String? detail) {
    if (detail == null) return '';
    return detail
        .replaceAll(RegExp(r'\[ID:\s*[^\]]+\]\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[เป้าหมาย:\s*[^\]]+\]\s*', caseSensitive: false), '')
        .trim();
  }

  /// Resolves profile image URL from regisimagepath (handles JSON string, URL, or relative storage path)
  String? _getDriverProfileImageUrl(dynamic regisImagePath) {
    if (regisImagePath == null) return null;
    String pathStr = regisImagePath.toString().trim();
    if (pathStr.isEmpty) return null;

    if (pathStr.startsWith('{')) {
      try {
        final decoded = jsonDecode(pathStr);
        if (decoded is Map && decoded['profile'] != null) {
          pathStr = decoded['profile'].toString();
        }
      } catch (_) {}
    } else if (pathStr.startsWith('[')) {
      try {
        final decoded = jsonDecode(pathStr);
        if (decoded is List && decoded.isNotEmpty) {
          pathStr = decoded.first.toString();
        }
      } catch (_) {}
    }

    if (pathStr.startsWith('http://') || pathStr.startsWith('https://')) {
      return pathStr;
    }

    while (pathStr.startsWith('/')) {
      pathStr = pathStr.substring(1);
    }
    if (pathStr.startsWith('images/')) {
      pathStr = pathStr.substring(7);
    }
    return Supabase.instance.client.storage.from('images').getPublicUrl(pathStr);
  }

  Future<void> _fetchReportedDrivers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final detail = widget.report.reportDetail ?? '';
      List<String> targetUsernames = _extractReportedDriverIds(detail);
      
      // Also fetch trip context (requestbyuser and buddyteam) to identify roles & fallback drivers
      String? leaderUsername;
      String? followerUsername;
      try {
        final reqRes = await Supabase.instance.client
            .from('requestbyuser')
            .select('requestid, buddy_team_id')
            .eq('requestid', widget.report.requestId)
            .maybeSingle();

        if (reqRes != null && reqRes['buddy_team_id'] != null) {
          final teamRes = await Supabase.instance.client
              .from('buddyteam')
              .select('leaderid, followerid')
              .eq('buddyteamid', reqRes['buddy_team_id'])
              .maybeSingle();

          if (teamRes != null) {
            leaderUsername = teamRes['leaderid']?.toString();
            followerUsername = teamRes['followerid']?.toString();
          }
        }
      } catch (e) {
        debugPrint('Error loading buddy team info: $e');
      }

      // If no ID tag was in reportDetail (legacy format), fallback to trip drivers
      if (targetUsernames.isEmpty) {
        if (detail.contains('ผู้ติดตาม') && followerUsername != null) {
          targetUsernames = [followerUsername];
        } else if (detail.contains('หัวหน้าทีม') && leaderUsername != null) {
          targetUsernames = [leaderUsername];
        } else {
          targetUsernames = [
            ?leaderUsername,
            ?followerUsername,
          ];
        }
      }

      final List<ReportedDriverInfo> drivers = [];

      if (targetUsernames.isNotEmpty) {
        // Query driver records with vehicle details
        final driverRows = await Supabase.instance.client
            .from('driver')
            .select('username, firstname, lastname, phoneno, regisimagepath, drivercar:driver_car(carbrand, carmodel, carplate)')
            .inFilter('username', targetUsernames);

        // Query reviews to calculate driver rating
        Map<String, double> driverRatings = {};
        try {
          final reviewsRes = await Supabase.instance.client
              .from('review')
              .select('driverusername, reviewrate')
              .inFilter('driverusername', targetUsernames);

          if (reviewsRes.isNotEmpty) {
            final Map<String, List<int>> map = {};
            for (var r in reviewsRes) {
              final u = r['driverusername']?.toString().toLowerCase();
              final rate = (r['reviewrate'] as num?)?.toInt();
              if (u != null && rate != null) {
                map.putIfAbsent(u, () => []).add(rate);
              }
            }
            map.forEach((u, rates) {
              if (rates.isNotEmpty) {
                final avg = rates.reduce((a, b) => a + b) / rates.length;
                driverRatings[u] = avg;
              }
            });
          }
        } catch (e) {
          debugPrint('Error loading driver reviews: $e');
        }

        if (driverRows.isNotEmpty) {
          for (var row in driverRows) {
            final u = row['username']?.toString() ?? '';
            final uLower = u.toLowerCase();
            
            // Determine role
            String role = 'ผู้ขับรถของคุณ';
            if (leaderUsername != null && uLower == leaderUsername.toLowerCase()) {
              role = 'คนขับหลัก (หัวหน้าทีม)';
            } else if (followerUsername != null && uLower == followerUsername.toLowerCase()) {
              role = 'ผู้ช่วยผู้ขับรถ (ผู้ติดตาม)';
            }

            final ratingVal = driverRatings[uLower];
            final ratingStr = ratingVal != null ? ratingVal.toStringAsFixed(1) : '5.0';

            String? carVehicle;
            if (row['drivercar'] != null && row['drivercar'] is Map) {
              final brand = row['drivercar']['carbrand']?.toString();
              final model = row['drivercar']['carmodel']?.toString();
              final plate = row['drivercar']['carplate']?.toString();
              final parts = <String>[];
              if (brand != null && brand.trim().isNotEmpty) parts.add(brand.trim());
              if (model != null && model.trim().isNotEmpty) parts.add(model.trim());
              final modelStr = parts.join(' ');
              if (modelStr.isNotEmpty && plate != null && plate.trim().isNotEmpty) {
                carVehicle = '$modelStr • $plate';
              } else if (modelStr.isNotEmpty) {
                carVehicle = modelStr;
              } else {
                carVehicle = plate;
              }
            }

            drivers.add(ReportedDriverInfo(
              username: u,
              fullname: '${row['firstname'] ?? ''} ${row['lastname'] ?? ''}'.trim(),
              role: role,
              phoneNo: row['phoneno']?.toString(),
              licensePlate: carVehicle,
              imageUrl: _getDriverProfileImageUrl(row['regisimagepath']),
              rating: ratingStr,
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _reportedDrivers = drivers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchReportedDrivers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTimeThai(DateTime? dateTime) {
    if (dateTime == null) return '';
    final months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];

    int hourInt = dateTime.hour;
    final displayPeriod = dateTime.hour >= 12 ? 'PM' : 'AM';
    if (hourInt > 12) hourInt -= 12;
    if (hourInt == 0) hourInt = 12;
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day $month ${dateTime.year} $hour:$minute $displayPeriod';
  }

  Widget _buildProgressBar(String status) {
    final isReviewing = status == 'กำลังดำเนินการ' || status == 'เสร็จสิ้น' || status == 'แก้ไขแล้ว';
    final isResolved = status == 'เสร็จสิ้น' || status == 'แก้ไขแล้ว';

    return Column(
      children: [
        Row(
          children: [
            // Segment 1: Submitted
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Segment 2: Reviewing
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: isResolved ? 1.0 : (isReviewing ? 0.5 : 0.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D47A1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Segment 3: Resolved
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isResolved ? const Color(0xFF0D47A1) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Submitted',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Reviewing',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isReviewing ? const Color(0xFF0D47A1) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Resolved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isResolved ? const Color(0xFF0D47A1) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverCard(ReportedDriverInfo driver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          DriverAvatar(
            imageUrl: driver.imageUrl,
            fallbackName: driver.fullname,
            radius: 28,
            badgeText: driver.role.contains('หัวหน้า') || driver.role.contains('คนขับหลัก') ? 'D1' : (driver.role.contains('ผู้ช่วย') ? 'D2' : null),
            badgeColor: driver.role.contains('หัวหน้า') || driver.role.contains('คนขับหลัก') ? const Color(0xFF0D47A1) : const Color(0xFF64748B),
            defaultIcon: driver.role.contains('ผู้ช่วย') ? Icons.motorcycle : Icons.person,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fullname.isNotEmpty ? driver.fullname : driver.username,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  driver.role,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                if (driver.phoneNo != null && driver.phoneNo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'โทร: ${driver.phoneNo}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  driver.rating,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, color: Colors.amber, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final status = report.reportStatus ?? 'กำลังดำเนินการ';
    final isResolved = status == 'เสร็จสิ้น' || status == 'แก้ไขแล้ว';

    final orderCode = '#ORD${report.requestId.toString().padLeft(4, '0')}';
    final dateStr = _formatDateTimeThai(report.reportDate);
    final cleanDetail = _cleanReportDetail(report.reportDetail);

    // Image Paths parsing
    final List<String> imagePaths = report.reportImagePath != null && report.reportImagePath!.isNotEmpty
        ? report.reportImagePath!.split(',').where((p) => p.trim().isNotEmpty).toList()
        : [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Status',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              orderCode,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: _fetchReportedDrivers,
          ),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchReportedDrivers,
          color: const Color(0xFF0D47A1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Central Status Illustration
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: Icon(
                          isResolved ? Icons.assignment_turned_in_rounded : Icons.pending_actions_rounded,
                          color: const Color(0xFF0D47A1),
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isResolved ? 'แก้ไขปัญหาเรียบร้อยแล้ว' : 'กำลังอยู่ระหว่างตรวจสอบ',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'รายงาน ณ วันที่ $dateStr',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 2. Progress status bar
                _buildProgressBar(status),
                const SizedBox(height: 36),

                // 3. Accused Driver Card(s)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _reportedDrivers.length > 1
                                ? 'ข้อมูลผู้ถูกรายงาน (${_reportedDrivers.length} คน)'
                                : 'ข้อมูลผู้ถูกรายงาน',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          if (_reportedDrivers.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_reportedDrivers.length} คนขับ',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading) ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ] else if (_reportedDrivers.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'ไม่มีข้อมูลคนขับที่ระบุในรายงานนี้',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ..._reportedDrivers.map((d) => _buildDriverCard(d)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Report Details & Description Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'รายละเอียดการรายงาน',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ประเภท: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              report.reportType,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (cleanDetail.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'คำอธิบายเหตุการณ์:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Text(
                            cleanDetail,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Two Grid Cards (Actions/Policy)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.security_rounded,
                              color: Color(0xFF0D47A1),
                              size: 24,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'SafeSeat Policy',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Our safety team is currently investigating your report.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              color: Color(0xFF0D47A1),
                              size: 24,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Need Help?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Chat with our 24/7 support if you have more details.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 6. Evidence Photos (Only show if present)
                if (imagePaths.isNotEmpty) ...[
                  const Text(
                    'รูปภาพหลักฐาน',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imagePaths.length,
                      itemBuilder: (context, index) {
                        final path = imagePaths[index];
                        final imageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(path);

                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    InteractiveViewer(
                                      child: Image.network(imageUrl),
                                    ),
                                    Positioned(
                                      top: 40,
                                      right: 20,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
