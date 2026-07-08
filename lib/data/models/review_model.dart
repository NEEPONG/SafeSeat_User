class ReviewModel {
  final int? reviewId;
  final String? reviewComment;
  final DateTime? reviewDate;
  final int reviewRate;
  final int requestId;
  final String driverUsername;

  ReviewModel({
    this.reviewId,
    this.reviewComment,
    this.reviewDate,
    required this.reviewRate,
    required this.requestId,
    required this.driverUsername,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      reviewId: json['reviewid'],
      reviewComment: json['reviewcomment'],
      reviewDate: json['reviewdate'] != null
          ? DateTime.tryParse(json['reviewdate'])
          : null,
      reviewRate: json['reviewrate'] ?? 0,
      requestId: json['request_id'] ?? 0,
      driverUsername: json['driverusername'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (reviewId != null) 'reviewid': reviewId,
      'reviewcomment': reviewComment,
      if (reviewDate != null) 'reviewdate': reviewDate!.toIso8601String(),
      'reviewrate': reviewRate,
      'request_id': requestId,
      'driverusername': driverUsername,
    };
  }
}
