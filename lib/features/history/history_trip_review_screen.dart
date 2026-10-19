import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/services/geocoding_service.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/core/utils/validators.dart';
import 'package:safeseat_mini/core/widgets/driver_avatar.dart';
import 'package:safeseat_mini/data/models/request_driver_model.dart';
import 'package:safeseat_mini/data/models/review_model.dart';
import 'package:safeseat_mini/features/history/controllers/history_controller.dart';

class HistoryTripReviewScreen extends ConsumerStatefulWidget {
  final RequestDriverModel trip;
  final List<ReviewModel>? existingReviews;
  final String? pickupAddress;
  final String? dropoffAddress;

  const HistoryTripReviewScreen({
    super.key,
    required this.trip,
    this.existingReviews,
    this.pickupAddress,
    this.dropoffAddress,
  });

  @override
  ConsumerState<HistoryTripReviewScreen> createState() =>
      _HistoryTripReviewScreenState();
}

class _HistoryTripReviewScreenState
    extends ConsumerState<HistoryTripReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  int _driverRating = 0;
  int _coDriverRating = 0;
  final TextEditingController _driverCommentController =
      TextEditingController();
  final TextEditingController _coDriverCommentController =
      TextEditingController();
  String? _pickupAddress;
  String? _dropoffAddress;
  bool _isLoadingPickupAddress = false;
  bool _isLoadingDropoffAddress = false;

  bool get isReadOnly =>
      widget.existingReviews != null && widget.existingReviews!.isNotEmpty;

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
    final reviews = widget.existingReviews;
    if (reviews != null && reviews.isNotEmpty) {
      // Leader review
      final leaderUsername = widget.trip.leader?.username;
      ReviewModel? leaderReview;
      if (leaderUsername != null) {
        leaderReview = reviews.firstWhere(
          (r) => r.driverUsername == leaderUsername,
          orElse: () => reviews.first,
        );
      } else {
        leaderReview = reviews.first;
      }
      _driverRating = leaderReview.reviewRate;
      _driverCommentController.text = leaderReview.reviewComment ?? '';

      // Follower review
      if (reviews.length > 1) {
        final followerUsername = widget.trip.follower?.username;
        ReviewModel? followerReview;
        if (followerUsername != null) {
          followerReview = reviews.firstWhere(
            (r) => r.driverUsername == followerUsername,
            orElse: () => reviews.last,
          );
        } else {
          followerReview = reviews.last;
        }
        _coDriverRating = followerReview.reviewRate;
        _coDriverCommentController.text = followerReview.reviewComment ?? '';
      }
    }
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

  @override
  void dispose() {
    _driverCommentController.dispose();
    _coDriverCommentController.dispose();
    super.dispose();
  }

  Widget _buildStarRating(int currentRating, Function(int)? onRatingChanged) {
    final bool isReadOnlyMode = onRatingChanged == null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isSelected = starIndex <= currentRating;
        return Flexible(
          child: Semantics(
            label: '$starIndex ดาว',
            button: !isReadOnlyMode,
            child: GestureDetector(
              onTap: isReadOnlyMode ? null : () => onRatingChanged(starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2.0,
                  vertical: 4,
                ),
                child: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isSelected ? Colors.amber : const Color(0xFFCBD5E1),
                  size: 36,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildReviewCard({
    required String name,
    required String role,
    String? avatarUrl,
    required String ratingLabel,
    required int currentRating,
    required Function(int) onRatingChanged,
    required TextEditingController controller,
    required String badgeText,
    required Color badgeColor,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile section
          Row(
            children: [
              DriverAvatar(
                imageUrl: avatarUrl,
                fallbackName: name,
                radius: 30,
                badgeText: badgeText,
                badgeColor: badgeColor,
                defaultIcon: badgeText == 'D2'
                    ? Icons.motorcycle
                    : Icons.person,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Rating prompt
          Text(
            ratingLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Star icons
          _buildStarRating(currentRating, isReadOnly ? null : onRatingChanged),
          const SizedBox(height: 16),
          // Comment box label
          const Text(
            'ความคิดเห็นเพิ่มเติม',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          // Textfield
          TextFormField(
            controller: controller,
            maxLines: 3,
            readOnly: isReadOnly,
            validator: validator,
            decoration: InputDecoration(
              hintText: 'บอกเราเกี่ยวกับประสบการณ์ของคุณ',
              hintStyle: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
              fillColor: AppTheme.backgroundColor,
              filled: true,
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.borderColor),
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
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderCode = '#ORD${widget.trip.requestId.toString().padLeft(4, '0')}';

    // Show only drivers actually assigned to this trip.
    final hasLeader = widget.trip.leader != null;
    final hasFollower = widget.trip.follower != null;
    final driverName = widget.trip.leader != null
        ? '${widget.trip.leader!.firstname} ${widget.trip.leader!.lastname}'
        : 'ยังไม่มีคนขับหลัก';

    final coDriverName = widget.trip.follower != null
        ? '${widget.trip.follower!.firstname} ${widget.trip.follower!.lastname}'
        : 'ยังไม่มีผู้ช่วยคนขับ';

    final pickupPoint = _isLoadingPickupAddress
        ? 'กำลังค้นหาชื่อสถานที่...'
        : (_pickupAddress ?? 'ไม่พบชื่อสถานที่');
    final dropoffPoint = _isLoadingDropoffAddress
        ? 'กำลังค้นหาชื่อสถานที่...'
        : (_dropoffAddress ?? 'ไม่พบชื่อสถานที่');

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
            Text(
              isReadOnly ? 'รีวิวของคุณ' : 'รีวิวการเดินทาง',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              orderCode,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 1. Trip Locations Card
                      Container(
                        padding: const EdgeInsets.all(16.0),
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
                        child: Row(
                          children: [
                            // Timeline indicators
                            Column(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: AppTheme.pickupColor,
                                  size: 20,
                                ),
                                Container(
                                  width: 1.5,
                                  height: 20,
                                  color: Colors.grey[300],
                                ),
                                const Icon(
                                  Icons.flag,
                                  color: AppTheme.dropoffColor,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Location details
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
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
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
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Distance info
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  '${widget.trip.reqDistance.toStringAsFixed(1)} กม.',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F3D8A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Driver Review Card
                      if (!hasLeader && !hasFollower)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'ยังไม่มีข้อมูลคนขับสำหรับการรีวิว',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      if (hasLeader)
                        _buildReviewCard(
                          name: driverName,
                          role: 'คนขับหลัก',
                          avatarUrl: widget.trip.leader?.resolvedImageUrl,
                          ratingLabel: 'ให้คะแนนคนขับหลัก',
                          currentRating: _driverRating,
                          onRatingChanged: (val) {
                            setState(() {
                              _driverRating = val;
                            });
                          },
                          controller: _driverCommentController,
                          badgeText: 'D1',
                          badgeColor: AppTheme.accentColor,
                          validator: AppValidators.validateReviewComment,
                        ),
                      if (hasLeader && hasFollower) const SizedBox(height: 16),

                      // 3. Co-driver Review Card
                      if (hasFollower)
                        _buildReviewCard(
                          name: coDriverName,
                          role: 'ผู้ช่วยคนขับ',
                          avatarUrl: widget.trip.follower?.resolvedImageUrl,
                          ratingLabel: 'ให้คะแนนผู้ช่วยคนขับ',
                          currentRating: _coDriverRating,
                          onRatingChanged: (val) {
                            setState(() {
                              _coDriverRating = val;
                            });
                          },
                          controller: _coDriverCommentController,
                          badgeText: 'D2',
                          badgeColor: const Color(0xFF475569),
                          validator: AppValidators.validateReviewComment,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Submit Button
            if (!isReadOnly && (hasLeader || hasFollower))
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if ((hasLeader && _driverRating == 0) ||
                          (hasFollower && _coDriverRating == 0)) {
                        AppSnackBar.showWarning(
                          context,
                          'กรุณาให้คะแนนคนขับก่อนส่งรีวิว',
                        );
                        return;
                      }

                      if (!_formKey.currentState!.validate()) {
                        return;
                      }

                      if (!context.mounted) return;
                      AppDialog.showLoading(
                        context,
                        message: 'กำลังบันทึกคะแนนรีวิว...',
                      );

                      try {
                        await ref
                            .read(historyReviewControllerProvider.notifier)
                            .submitTripReviews(
                              requestId: widget.trip.requestId,
                              leaderUsername: widget.trip.leader?.username,
                              leaderRating: _driverRating,
                              leaderComment: _driverCommentController.text,
                              followerUsername: widget.trip.follower?.username,
                              followerRating: _coDriverRating,
                              followerComment: _coDriverCommentController.text,
                            );

                        if (!context.mounted) return;
                        AppDialog.hideLoading(context);

                        AppSnackBar.showSuccess(
                          context,
                          'ส่งรีวิวสำเร็จ ขอบคุณสำหรับความคิดเห็นของคุณ',
                        );
                        Navigator.of(context).pop();
                      } catch (e) {
                        if (!context.mounted) return;
                        AppDialog.hideLoading(context);

                        AppSnackBar.showError(
                          context,
                          'เกิดข้อผิดพลาดในการส่งรีวิว: $e',
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    label: const Text(
                      'ส่งรีวิว',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
