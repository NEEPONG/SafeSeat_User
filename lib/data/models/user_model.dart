import 'dart:convert';
import 'package:latlong2/latlong.dart';

class UserModel {
  final String phoneNo;
  final String email;
  final int gender;
  final String? mainAddress;
  final String name;
  final String? profileImagePath;
  final num walletBalance;

  UserModel({
    required this.phoneNo,
    required this.email,
    required this.gender,
    this.mainAddress,
    required this.name,
    this.profileImagePath,
    this.walletBalance = 0.0,
  });

  /// Returns the human-readable custom name / address for Home
  String? get homeDisplayName {
    if (mainAddress == null || mainAddress!.trim().isEmpty) return null;
    try {
      final trimmed = mainAddress!.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final Map<String, dynamic> data = jsonDecode(trimmed);
        if (data.containsKey('name')) {
          return data['name'] as String?;
        }
      }
    } catch (_) {}
    return mainAddress;
  }

  /// Returns exact latitude pinned by user
  double? get homeLatitude {
    if (mainAddress == null || mainAddress!.trim().isEmpty) return null;
    try {
      final trimmed = mainAddress!.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final Map<String, dynamic> data = jsonDecode(trimmed);
        if (data.containsKey('lat') && data['lat'] != null) {
          return (data['lat'] as num).toDouble();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Returns exact longitude pinned by user
  double? get homeLongitude {
    if (mainAddress == null || mainAddress!.trim().isEmpty) return null;
    try {
      final trimmed = mainAddress!.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final Map<String, dynamic> data = jsonDecode(trimmed);
        if (data.containsKey('lng') && data['lng'] != null) {
          return (data['lng'] as num).toDouble();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Returns exact LatLng object pinned by user
  LatLng? get homeLatLng {
    final lat = homeLatitude;
    final lng = homeLongitude;
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      return LatLng(lat, lng);
    }
    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      phoneNo: json['phoneno'] ?? '',
      email: json['email'] ?? '',
      gender: json['gender'] ?? 0,
      mainAddress: json['mainaddress'],
      name: json['name'] ?? '',
      profileImagePath: json['profileimagepath'],
      walletBalance: json['walletbalance'] ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneno': phoneNo,
      'email': email,
      'gender': gender,
      'mainaddress': mainAddress,
      'name': name,
      'profileimagepath': profileImagePath,
      'walletbalance': walletBalance,
    };
  }

  UserModel copyWith({
    String? phoneNo,
    String? email,
    int? gender,
    String? mainAddress,
    String? name,
    String? profileImagePath,
    num? walletBalance,
  }) {
    return UserModel(
      phoneNo: phoneNo ?? this.phoneNo,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      mainAddress: mainAddress ?? this.mainAddress,
      name: name ?? this.name,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}
