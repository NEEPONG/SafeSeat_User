import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safeseat_mini/data/models/driver_report_model.dart';

class HistoryReportDetailsScreen extends StatelessWidget {
  final DriverReportModel report;

  const HistoryReportDetailsScreen({super.key, required this.report});

  String _formatDateTimeThai(DateTime? dateTime) {
    if (dateTime == null) return '';
    final months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    
    // Format AM/PM
    int hourInt = dateTime.hour;
    final period = hourInt >= 12 ? 'AM' : 'AM'; // Match standard format or display AM/PM
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

  @override
  Widget build(BuildContext context) {
    final status = report.reportStatus ?? 'กำลังดำเนินการ';
    final isResolved = status == 'เสร็จสิ้น' || status == 'แก้ไขแล้ว';
    
    final orderCode = '#ORD${report.requestId.toString().padLeft(4, '0')}';
    final dateStr = _formatDateTimeThai(report.reportDate);

    // Identify which driver to show from requestByUser nested map
    Map<String, dynamic>? driverToShow;
    String roleLabel = 'ผู้ขับรถของคุณ';
    
    final req = report.requestByUser;
    if (req != null) {
      final leader = req['leader'];
      final follower = req['follower'];
      final detail = report.reportDetail ?? '';
      
      if (detail.contains('ผู้ติดตาม') && follower != null) {
        driverToShow = follower;
        roleLabel = 'ผู้ช่วยผู้ขับรถ';
      } else if (leader != null) {
        driverToShow = leader;
        roleLabel = 'ผู้ขับรถของคุณ';
      }
    }

    // Default mock data if driver details are empty
    final driverName = driverToShow != null
        ? '${driverToShow['firstname']} ${driverToShow['lastname']}'
        : 'นายไอติม สุดหล่อเท่';
    final driverRating = '4.7';

    // Image Paths parsing
    final List<String> imagePaths = report.reportImagePath != null && report.reportImagePath!.isNotEmpty
        ? report.reportImagePath!.split(',').where((p) => p.trim().isNotEmpty).toList()
        : [];

    String? driverImageUrl;
    if (driverToShow != null && driverToShow['regisimagepath'] != null) {
      String path = driverToShow['regisimagepath'] as String;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        driverImageUrl = path;
      } else {
        // Strip any leading slashes
        while (path.startsWith('/')) {
          path = path.substring(1);
        }
        // Strip "images/" bucket prefix since we query from('images')
        if (path.startsWith('images/')) {
          path = path.substring(7); // 'images/'.length is 7
        }
        driverImageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(path);
      }
    }

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
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CenterPlayground.crossAxisAlignment,
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

              // 3. Accused Driver Card
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
                      'ข้อมูลผู้ถูกรายงาน',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: driverImageUrl != null
                                  ? NetworkImage(driverImageUrl)
                                  : null,
                              child: driverImageUrl == null
                                  ? const Icon(Icons.person, color: Colors.grey, size: 32)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0D47A1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
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
                              const SizedBox(height: 4),
                              Text(
                                roleLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                driverRating,
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Two Grid Cards (Actions/Policy)
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

              // 5. Evidence Photos (Only show if present)
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
    );
  }
}

class CenterPlayground {
  static const crossAxisAlignment = CrossAxisAlignment.start;
}
