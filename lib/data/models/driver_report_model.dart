class DriverReportModel {
  final int? driverReportId;
  final DateTime? reportDate;
  final String? reportDetail;
  final String? reportImagePath;
  final int reportIndex;
  final String? reportStatus;
  final String reportType;
  final int requestId;
  final Map<String, dynamic>? requestByUser;

  DriverReportModel({
    this.driverReportId,
    this.reportDate,
    this.reportDetail,
    this.reportImagePath,
    required this.reportIndex,
    this.reportStatus,
    required this.reportType,
    required this.requestId,
    this.requestByUser,
  });

  factory DriverReportModel.fromJson(Map<String, dynamic> json) {
    return DriverReportModel(
      driverReportId: json['driverreportid'],
      reportDate: json['reportdate'] != null
          ? DateTime.tryParse(json['reportdate'])
          : null,
      reportDetail: json['reportdetail'],
      reportImagePath: json['reportimagepath'],
      reportIndex: json['reportindex'] ?? 0,
      reportStatus: json['reportstatus'],
      reportType: json['reporttype'] ?? '',
      requestId: json['request_id'] ?? 0,
      requestByUser: json['requestbyuser'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (driverReportId != null) 'driverreportid': driverReportId,
      if (reportDate != null) 'reportdate': reportDate!.toIso8601String(),
      'reportdetail': reportDetail,
      'reportimagepath': reportImagePath,
      'reportindex': reportIndex,
      if (reportStatus != null) 'reportstatus': reportStatus,
      'reporttype': reportType,
      'request_id': requestId,
      if (requestByUser != null) 'requestbyuser': requestByUser,
    };
  }
}
