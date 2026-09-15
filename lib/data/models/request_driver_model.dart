import 'dart:convert';
import 'package:safeseat_mini/data/models/car_model.dart';

class DriverProfileModel {
  final String username;
  final String firstname;
  final String lastname;
  final String phoneNo;
  final String? licensePlate;
  final String? profileImage;
  final double? rating;
  final int? totalReviews;
  final String? carBrand;
  final String? carModel;
  final String? carColor;
  final String? carImage;

  DriverProfileModel({
    required this.username,
    required this.firstname,
    required this.lastname,
    required this.phoneNo,
    this.licensePlate,
    this.profileImage,
    this.rating,
    this.totalReviews,
    this.carBrand,
    this.carModel,
    this.carColor,
    this.carImage,
  });

  String get fullName => '$firstname $lastname'.trim().isNotEmpty ? '$firstname $lastname'.trim() : username;

  /// แสดงข้อความสรุปยานพาหนะของคนขับ (เช่น "Honda Wave 125i • 1กข 1234" หรือ "ทะเบียน 1กข 1234")
  String get vehicleSummary {
    final parts = <String>[];
    if (carBrand != null && carBrand!.trim().isNotEmpty) parts.add(carBrand!.trim());
    if (carModel != null && carModel!.trim().isNotEmpty) parts.add(carModel!.trim());
    final modelStr = parts.join(' ');
    final plate = licensePlate?.trim() ?? '';

    if (modelStr.isNotEmpty && plate.isNotEmpty) {
      return '$modelStr • $plate';
    } else if (modelStr.isNotEmpty) {
      return modelStr;
    } else if (plate.isNotEmpty) {
      return 'ทะเบียน $plate';
    }
    return 'ไม่ระบุยานพาหนะ';
  }

  String? get resolvedImageUrl {
    if (profileImage == null || profileImage!.trim().isEmpty) return null;
    String raw = profileImage!.trim();

    // Check if JSON formatted string
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['profile'] != null) {
          raw = decoded['profile'].toString();
        }
      } catch (_) {}
    } else if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          raw = decoded.first.toString();
        }
      } catch (_) {}
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    // Handle compressed prefix
    if (raw.startsWith('p:')) {
      raw = 'drivers/profile/${raw.substring(2)}';
    } else if (raw.startsWith('d:')) {
      raw = 'drivers/documents/${raw.substring(2)}';
    }

    while (raw.startsWith('/')) {
      raw = raw.substring(1);
    }
    if (raw.startsWith('images/')) {
      raw = raw.substring(7);
    }

    const baseUrl = 'https://qbionbozkvlekpakvstg.supabase.co';
    return '$baseUrl/storage/v1/object/public/images/$raw';
  }

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    // Parse rating safely (can be int, double, or string)
    double? parsedRating;
    if (json['rating'] != null) {
      parsedRating = double.tryParse(json['rating'].toString());
    } else if (json['average_rating'] != null) {
      parsedRating = double.tryParse(json['average_rating'].toString());
    }

    int? parsedReviews;
    if (json['total_reviews'] != null) {
      parsedReviews = int.tryParse(json['total_reviews'].toString());
    }

    // Parse driver car fields
    String? plate = json['license_plate']?.toString();
    String? brand;
    String? model;
    String? color;
    String? img;

    if (json['driver_car'] is Map) {
      final dc = json['driver_car'] as Map;
      plate = plate ?? dc['plate']?.toString() ?? dc['carplate']?.toString();
      brand = dc['brand']?.toString() ?? dc['carbrand']?.toString();
      model = dc['model']?.toString() ?? dc['carmodel']?.toString();
      color = dc['color']?.toString() ?? dc['carcolor']?.toString();
      img = dc['image']?.toString() ?? dc['carimagepath']?.toString();
    } else if (json['drivercar'] is Map) {
      final dc = json['drivercar'] as Map;
      plate = plate ?? dc['carplate']?.toString() ?? dc['plate']?.toString();
      brand = dc['carbrand']?.toString() ?? dc['brand']?.toString();
      model = dc['carmodel']?.toString() ?? dc['model']?.toString();
      color = dc['carcolor']?.toString() ?? dc['color']?.toString();
      img = dc['carimagepath']?.toString() ?? dc['image']?.toString();
    }

    return DriverProfileModel(
      username: json['username'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      phoneNo: json['phone_no'] ?? json['phoneno'] ?? '',
      licensePlate: plate,
      profileImage: json['profile_image'] ?? json['profileimagepath'] ?? json['regisimagepath'],
      rating: parsedRating,
      totalReviews: parsedReviews,
      carBrand: brand,
      carModel: model,
      carColor: color,
      carImage: img,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'firstname': firstname,
      'lastname': lastname,
      'phone_no': phoneNo,
      'license_plate': licensePlate,
      'profile_image': profileImage,
      'rating': rating,
      'total_reviews': totalReviews,
      'car_brand': carBrand,
      'car_model': carModel,
      'car_color': carColor,
      'car_image': carImage,
    };
  }
}

class BuddyTeamModel {
  final int buddyTeamId;
  final String leaderId;
  final String followerId;
  final String teamStatus;
  final double? currentLocLat;
  final double? currentLocLng;

  BuddyTeamModel({
    required this.buddyTeamId,
    required this.leaderId,
    required this.followerId,
    required this.teamStatus,
    this.currentLocLat,
    this.currentLocLng,
  });

  factory BuddyTeamModel.fromJson(Map<String, dynamic> json) {
    return BuddyTeamModel(
      buddyTeamId: json['buddyteamid'] ?? 0,
      leaderId: json['leaderid'] ?? '',
      followerId: json['followerid'] ?? '',
      teamStatus: json['teamstatus'] ?? '',
      currentLocLat: (json['currentloclat'] as num?)?.toDouble(),
      currentLocLng: (json['currentloclng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buddyteamid': buddyTeamId,
      'leaderid': leaderId,
      'followerid': followerId,
      'teamstatus': teamStatus,
      'currentloclat': currentLocLat,
      'currentloclng': currentLocLng,
    };
  }
}

class RequestDriverModel {
  final int requestId;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final bool isLadyMode;
  final String? note;
  final int paymentMethod;
  final double reqDistance;
  final double requestFee;
  final String requestStatus;
  final String reqDateTime;
  final String? finishJobPicPath;
  final int? buddyTeamId;
  final String userId;
  final int userCarId;
  final BuddyTeamModel? buddyTeam;
  final DriverProfileModel? leader;
  final DriverProfileModel? follower;
  final CarModel? userCar;

  RequestDriverModel({
    required this.requestId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.isLadyMode,
    this.note,
    required this.paymentMethod,
    required this.reqDistance,
    required this.requestFee,
    required this.requestStatus,
    required this.reqDateTime,
    this.finishJobPicPath,
    this.buddyTeamId,
    required this.userId,
    required this.userCarId,
    this.buddyTeam,
    this.leader,
    this.follower,
    this.userCar,
  });

  factory RequestDriverModel.fromJson(Map<String, dynamic> json) {
    return RequestDriverModel(
      requestId: json['requestid'] ?? 0,
      pickupLatitude: (json['pickuplatitude'] as num?)?.toDouble() ?? 0.0,
      pickupLongitude: (json['pickuplongitude'] as num?)?.toDouble() ?? 0.0,
      dropoffLatitude: (json['dropofflatitude'] as num?)?.toDouble() ?? 0.0,
      dropoffLongitude: (json['dropofflongitude'] as num?)?.toDouble() ?? 0.0,
      isLadyMode: json['isladymode'] ?? false,
      note: json['note'],
      paymentMethod: json['paymentmethod'] ?? 1,
      reqDistance: (json['reqdistance'] as num?)?.toDouble() ?? 0.0,
      requestFee: (json['requestfee'] as num?)?.toDouble() ?? 0.0,
      requestStatus: json['requeststatus'] ?? '',
      reqDateTime: json['reqdatetime'] ?? '',
      finishJobPicPath: json['finishjobpicpath'],
      buddyTeamId: json['buddy_team_id'],
      userId: json['user_id'] ?? '',
      userCarId: json['user_car_id'] ?? 0,
      buddyTeam: json['buddyteam'] != null ? BuddyTeamModel.fromJson(json['buddyteam']) : null,
      leader: json['leader'] != null ? DriverProfileModel.fromJson(json['leader']) : null,
      follower: json['follower'] != null ? DriverProfileModel.fromJson(json['follower']) : null,
      userCar: json['usercar'] != null ? CarModel.fromJson(json['usercar']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestid': requestId,
      'pickuplatitude': pickupLatitude,
      'pickuplongitude': pickupLongitude,
      'dropofflatitude': dropoffLatitude,
      'dropofflongitude': dropoffLongitude,
      'isladymode': isLadyMode,
      'note': note,
      'paymentmethod': paymentMethod,
      'reqdistance': reqDistance,
      'requestfee': requestFee,
      'requeststatus': requestStatus,
      'reqdatetime': reqDateTime,
      'finishjobpicpath': finishJobPicPath,
      'buddy_team_id': buddyTeamId,
      'user_id': userId,
      'user_car_id': userCarId,
      'buddyteam': buddyTeam?.toJson(),
      'leader': leader?.toJson(),
      'follower': follower?.toJson(),
      'usercar': userCar?.toJson(),
    };
  }
}
