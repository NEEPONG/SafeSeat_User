import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const HistoryTripReviewScreen({
    super.key,
    required this.trip,
    this.existingReviews,
  });

  @override
  ConsumerState<HistoryTripReviewScreen> createState() => _HistoryTripReviewScreenState();
}

class _HistoryTripReviewScreenState extends ConsumerState<HistoryTripReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  int _driverRating = 0;
  int _coDriverRating = 0;
  final TextEditingController _driverCommentController = TextEditingController();
  final TextEditingController _coDriverCommentController = TextEditingController();

  bool get isReadOnly => widget.existingReviews != null && widget.existingReviews!.isNotEmpty;

  @override
  void initState() {
    super.initState();
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
        return GestureDetector(
          onTap: isReadOnlyMode ? null : () => onRatingChanged(starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              color: isSelected ? Colors.amber : const Color(0xFFCBD5E1),
              size: 40,
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
                defaultIcon: role.toLowerCase().contains('co') ? Icons.motorcycle : Icons.person,
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
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
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
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          // Star icons
          _buildStarRating(currentRating, isReadOnly ? null : onRatingChanged),
          const SizedBox(height: 16),
          // Comment box label
          const Text(
            'ความคิดเห็นเพิ่มเติมสำหรับผู้ช่วยผู้ขับรถ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
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
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
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
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderCode = '#ORD${widget.trip.requestId.toString().padLeft(4, '0')}';
    
    // Real or mock drivers check
    final driverName = widget.trip.leader != null
        ? '${widget.trip.leader!.firstname} ${widget.trip.leader!.lastname}'
        : 'นายไอติม สุดหล่อเท่';
        
    final coDriverName = widget.trip.follower != null
        ? '${widget.trip.follower!.firstname} ${widget.trip.follower!.lastname}'
        : 'คุณหญิงนิ่ม สุดสวยเท่';

    final pickupPoint = widget.trip.note != null && widget.trip.note!.isNotEmpty
        ? widget.trip.note!
        : 'ผับคุณหนูนิ่มประจำเชียงใหม่';
    const dropoffPoint = 'บ้านนิ่มเชียงใหม่แสนไกล';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            Text(
              isReadOnly ? 'รีวิวของคุณ' : 'Review Trip',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              orderCode,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                              const Icon(Icons.location_on, color: Colors.blue, size: 20),
                              Container(
                                width: 1.5,
                                height: 20,
                                color: Colors.grey[300],
                              ),
                              const Icon(Icons.radio_button_checked, color: Colors.black, size: 20),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Location details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PICKUP POINT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  pickupPoint,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'DROP-OFF POINT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  dropoffPoint,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
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
                                'TOTAL DISTANCE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.trip.reqDistance.toStringAsFixed(1)} KM',
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
                    _buildReviewCard(
                      name: driverName,
                      role: 'Driver',
                      avatarUrl: widget.trip.leader?.resolvedImageUrl,
                      ratingLabel: 'Rate your driver',
                      currentRating: _driverRating,
                      onRatingChanged: (val) {
                        setState(() {
                          _driverRating = val;
                        });
                      },
                      controller: _driverCommentController,
                      badgeText: 'D1',
                      badgeColor: const Color(0xFF2563EB),
                      validator: AppValidators.validateReviewComment,
                    ),
                    const SizedBox(height: 16),

                    // 3. Co-driver Review Card
                    _buildReviewCard(
                      name: coDriverName,
                      role: 'Co-driver',
                      avatarUrl: widget.trip.follower?.resolvedImageUrl,
                      ratingLabel: 'Rate your co-driver',
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
            if (!isReadOnly)
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
                    if (_driverRating == 0 || _coDriverRating == 0) {
                      AppSnackBar.showWarning(
                        context,
                        'กรุณาเลือกคะแนนความพึงพอใจให้ครบทั้งสองท่านก่อนยืนยัน',
                      );
                      return;
                    }

                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    if (!context.mounted) return;
                    AppDialog.showLoading(context, message: 'กำลังบันทึกคะแนนรีวิว...');

                    try {
                      await ref.read(historyReviewControllerProvider.notifier).submitTripReviews(
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
                    backgroundColor: const Color(0xFF0D47A1),
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
