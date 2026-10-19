import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safeseat_mini/core/services/geocoding_service.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/core/utils/validators.dart';
import 'package:safeseat_mini/core/widgets/driver_avatar.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';
import 'package:safeseat_mini/features/history/controllers/history_controller.dart';

class HistoryTripReportScreen extends ConsumerStatefulWidget {
  final RequestDriverModel trip;
  final String? pickupAddress;
  final String? dropoffAddress;

  const HistoryTripReportScreen({
    super.key,
    required this.trip,
    this.pickupAddress,
    this.dropoffAddress,
  });

  @override
  ConsumerState<HistoryTripReportScreen> createState() =>
      _HistoryTripReportScreenState();
}

class _HistoryTripReportScreenState
    extends ConsumerState<HistoryTripReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedCategory;
  String _selectedTarget = 'ALL';
  final List<File> _selectedImages = [];
  final _imagePicker = ImagePicker();
  String? _pickupAddress;
  String? _dropoffAddress;
  bool _isLoadingPickupAddress = false;
  bool _isLoadingDropoffAddress = false;

  final List<String> _categories = [
    'พฤติกรรมไม่เหมาะสม',
    'ขับรถอันตราย',
    'เรียกเก็บเงินเกินจริง',
    'ทรัพย์สินเสียหาย',
    'อื่นๆ (โปรดระบุในคำอธิบาย)',
  ];

  @override
  void initState() {
    super.initState();
    _pickupAddress = widget.pickupAddress;
    _dropoffAddress = widget.dropoffAddress;
    if (_pickupAddress == null) {
      _isLoadingPickupAddress = true;
      _resolveAddress(
        widget.trip.pickupLatitude,
        widget.trip.pickupLongitude,
        isPickup: true,
      );
    }
    if (_dropoffAddress == null) {
      _isLoadingDropoffAddress = true;
      _resolveAddress(
        widget.trip.dropoffLatitude,
        widget.trip.dropoffLongitude,
        isPickup: false,
      );
    }
    // Initialize default target based on available drivers
    final trip = widget.trip;
    if (trip.leader != null && trip.follower != null) {
      _selectedTarget = 'ALL';
    } else if (trip.leader != null) {
      _selectedTarget = 'LEADER';
    } else if (trip.follower != null) {
      _selectedTarget = 'FOLLOWER';
    } else {
      _selectedTarget = 'ALL';
    }

    _checkExistingReport();
  }

  Future<void> _resolveAddress(
    double latitude,
    double longitude, {
    required bool isPickup,
  }) async {
    String? name;
    try {
      name = await GeocodingService.reverseGeocode(latitude, longitude);
    } catch (_) {
      // The page keeps a readable fallback if the lookup fails.
    }
    if (!mounted) return;
    setState(() {
      if (isPickup) {
        _pickupAddress = name;
        _isLoadingPickupAddress = false;
      } else {
        _dropoffAddress = name;
        _isLoadingDropoffAddress = false;
      }
    });
  }

  Future<void> _checkExistingReport() async {
    try {
      final status = await ref
          .read(historyReportControllerProvider.notifier)
          .checkReportStatus(widget.trip.requestId);
      if (status['hasReported'] == true && mounted) {
        AppSnackBar.showWarning(
          context,
          'รายการนี้เคยถูกรายงานไปแล้ว ไม่สามารถรายงานซ้ำได้',
        );
        Navigator.of(context).pop();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) {
      AppSnackBar.showWarning(
        context,
        'คุณสามารถอัปโหลดรูปภาพหลักฐานได้สูงสุด 5 รูปภาพ',
      );
      return;
    }

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final path = pickedFile.path.toLowerCase();
        if (!path.endsWith('.png') &&
            !path.endsWith('.jpg') &&
            !path.endsWith('.jpeg')) {
          if (mounted) {
            AppSnackBar.showWarning(
              context,
              'รองรับเฉพาะไฟล์รูปภาพนามสกุล .png, .jpg, .jpeg เท่านั้น',
            );
          }
          return;
        }

        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null || !_formKey.currentState!.validate()) {
      AppSnackBar.showWarning(
        context,
        'กรุณาเลือกประเภทปัญหาและกรอกรายละเอียดให้ถูกต้องครบถ้วน',
      );
      return;
    }

    // Show standardized loading indicator
    AppDialog.showLoading(
      context,
      message: 'กำลังส่งข้อมูลรายงานและอัปโหลดหลักฐาน...',
    );

    try {
      // 1. Prepare report index based on selected category
      final reportIndex = _categories.indexOf(_selectedCategory!);

      // Collect target driver ID(s)
      final List<String> targetDriverIds = [];
      final leader = widget.trip.leader;
      final follower = widget.trip.follower;

      if (_selectedTarget == 'ALL') {
        if (leader != null && leader.username.isNotEmpty) {
          targetDriverIds.add(leader.username);
        }
        if (follower != null && follower.username.isNotEmpty) {
          targetDriverIds.add(follower.username);
        }
      } else if (_selectedTarget == 'LEADER') {
        if (leader != null && leader.username.isNotEmpty) {
          targetDriverIds.add(leader.username);
        }
      } else if (_selectedTarget == 'FOLLOWER') {
        if (follower != null && follower.username.isNotEmpty) {
          targetDriverIds.add(follower.username);
        }
      }

      // Format report detail: [ID: id1,id2] detail text
      String detailText = _descriptionController.text.trim();
      if (targetDriverIds.isNotEmpty) {
        detailText = '[ID: ${targetDriverIds.join(',')}] $detailText';
      }
      // Ensure maximum length of 255 characters for database varchar(255)
      if (detailText.length > 255) {
        detailText = detailText.substring(0, 255);
      }

      // 2. Submit via historyReportControllerProvider
      final success = await ref
          .read(historyReportControllerProvider.notifier)
          .submitDriverReport(
            requestId: widget.trip.requestId,
            reportType: _selectedCategory!,
            reportDetail: detailText,
            reportIndex: reportIndex,
            images: _selectedImages,
          );

      if (!mounted) return;
      AppDialog.hideLoading(context);

      if (success) {
        ref.invalidate(userReportsListProvider);
        // Show success dialog
        AppDialog.showSuccess(
          context: context,
          title: 'ส่งรายงานสำเร็จ',
          message: 'ส่งรายงานแล้ว คุณติดตามสถานะได้ในประวัติการเดินทาง',
          buttonText: 'ตกลง',
          onDismiss: () {
            if (mounted) {
              Navigator.of(context).pop(true); // pop report screen with success
            }
          },
        );
      } else {
        AppSnackBar.showError(
          context,
          'ส่งรายงานไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialog.hideLoading(context);
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        AppSnackBar.showError(context, errorMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final orderCode = '#ORD${trip.requestId.toString().padLeft(4, '0')}';

    final pickupPoint = _isLoadingPickupAddress
        ? 'กำลังค้นหาชื่อสถานที่...'
        : (_pickupAddress ?? 'ไม่พบชื่อสถานที่');
    final dropoffPoint = _isLoadingDropoffAddress
        ? 'กำลังค้นหาชื่อสถานที่...'
        : (_dropoffAddress ?? 'ไม่พบชื่อสถานที่');

    // Build the driver targets list based on available drivers
    final List<DropdownMenuItem<String>> targetItems = [];
    if (trip.leader != null && trip.follower != null) {
      targetItems.add(
        const DropdownMenuItem(
          value: 'ALL',
          child: Text('ทุกคนในทริปนี้ (ทั้ง 2 คน)'),
        ),
      );
    }
    if (trip.leader != null) {
      targetItems.add(
        DropdownMenuItem(
          value: 'LEADER',
          child: Text(
            'คนขับหลัก (${trip.leader!.firstname} ${trip.leader!.lastname})',
          ),
        ),
      );
    }
    if (trip.follower != null) {
      targetItems.add(
        DropdownMenuItem(
          value: 'FOLLOWER',
          child: Text(
            'ผู้ช่วยคนขับ (${trip.follower!.firstname} ${trip.follower!.lastname})',
          ),
        ),
      );
    }
    if (targetItems.isEmpty) {
      targetItems.add(
        const DropdownMenuItem(value: 'ALL', child: Text('ผู้ขับรถในทริปนี้')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รายงานทริป',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              orderCode,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Trip Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Map Pins & Line
                      Column(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.pickupColor,
                            size: 20,
                          ),
                          Container(
                            width: 2,
                            height: 36,
                            color: const Color(0xFFCBD5E1),
                          ),
                          const Icon(
                            Icons.flag,
                            color: AppTheme.dropoffColor,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'จุดรับ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              pickupPoint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'จุดส่ง',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              dropoffPoint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Distance Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'ระยะทาง',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${trip.reqDistance.toStringAsFixed(1)} กม.',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Drivers involved
                const Text(
                  'ผู้เกี่ยวข้องกับทริปนี้',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      if (trip.leader != null) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: DriverAvatar(
                            imageUrl: trip.leader!.resolvedImageUrl,
                            fallbackName:
                                '${trip.leader!.firstname} ${trip.leader!.lastname}',
                            radius: 22,
                            badgeText: 'D1',
                            badgeColor: AppTheme.primaryColor,
                          ),
                          title: Text(
                            '${trip.leader!.firstname} ${trip.leader!.lastname}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'ผู้ขับรถส่งคุณ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: trip.leader!.rating == null
                              ? null
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.borderColor,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        trip.leader!.rating!.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                      if (trip.follower != null) ...[
                        if (trip.leader != null)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppTheme.borderColor,
                          ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: DriverAvatar(
                            imageUrl: trip.follower!.resolvedImageUrl,
                            fallbackName:
                                '${trip.follower!.firstname} ${trip.follower!.lastname}',
                            radius: 22,
                            badgeText: 'D2',
                            badgeColor: AppTheme.textSecondary,
                            defaultIcon: Icons.motorcycle,
                          ),
                          title: Text(
                            '${trip.follower!.firstname} ${trip.follower!.lastname}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'ผู้ช่วยผู้ขับรถ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: trip.follower!.rating == null
                              ? null
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.borderColor,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        trip.follower!.rating!.toStringAsFixed(
                                          1,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Dropdowns and Input
                const Text(
                  'ประเภทเหตุการณ์',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  hint: const Text(
                    'กรุณาเลือกประเภท',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                  initialValue: _selectedCategory,
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'ระบุคนที่ต้องการรายงาน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  initialValue: _selectedTarget,
                  items: targetItems,
                  onChanged: (val) {
                    setState(() {
                      _selectedTarget = val ?? 'ALL';
                    });
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'คำอธิบายเหตุการณ์',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 200,
                  validator: AppValidators.validateReportDetail,
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    hintText: 'บอกเราสิว่าเกิดอะไรขึ้น...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Evidence (Image Upload)
                const Text(
                  'หลักฐาน (รูปภาพ)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Images Grid List
                if (_selectedImages.isNotEmpty) ...[
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12, top: 8),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(_selectedImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Upload Area
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.borderColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.camera_enhance_outlined,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'อัปโหลดรูปภาพ หรือจับภาพหน้าจอ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'สูงสุด 5 รูปภาพ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // 5. Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ส่งรายงาน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.send, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
