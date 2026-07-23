class CarModel {
  final int userCarId;
  final String carBrand;
  final String carColor;
  final String carModel;
  final String carPlate;
  final int carType;
  final String userId;
  final String? carTypeName; // Derived from joined cartype table

  CarModel({
    required this.userCarId,
    required this.carBrand,
    required this.carColor,
    required this.carModel,
    required this.carPlate,
    required this.carType,
    required this.userId,
    this.carTypeName,
  });

  factory CarModel.fromJson(Map<String, dynamic> json) {
    return CarModel(
      userCarId: json['usercarid'] ?? 0,
      carBrand: json['carbrand'] ?? '',
      carColor: json['carcolor'] ?? '',
      carModel: json['carmodel'] ?? '',
      carPlate: json['carplate'] ?? '',
      carType: json['car_type'] ?? 0,
      userId: json['user_id'] ?? '',
      carTypeName: json['cartype'] != null ? json['cartype']['cartypename'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usercarid': userCarId,
      'carbrand': carBrand,
      'carcolor': carColor,
      'carmodel': carModel,
      'carplate': carPlate,
      'car_type': carType,
      'user_id': userId,
    };
  }
}
