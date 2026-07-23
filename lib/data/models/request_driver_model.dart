import 'package:safeseat_mini/data/models/car_model.dart';

class DriverProfileModel {
  final String username;
  final String firstname;
  final String lastname;
  final String phoneNo;
  final String? licensePlate;

  DriverProfileModel({
    required this.username,
    required this.firstname,
    required this.lastname,
    required this.phoneNo,
    this.licensePlate,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      username: json['username'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      phoneNo: json['phone_no'] ?? '',
      licensePlate: json['license_plate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'firstname': firstname,
      'lastname': lastname,
      'phone_no': phoneNo,
      'license_plate': licensePlate,
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
