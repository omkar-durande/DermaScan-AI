import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile model
class UserModel {
  final String uid;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? skinType; // Fitzpatrick I-VI
  final int? age;
  final List<String>? allergies;
  final Map<String, bool> notifications;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.skinType,
    this.age,
    this.allergies,
    this.notifications = const {
      'scanReminders': true,
      'treatmentReminders': true,
      'uvAlerts': true,
    },
    required this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      skinType: json['skinType'] as String?,
      age: json['age'] as int?,
      allergies: (json['allergies'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      notifications:
          (json['notifications'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, value as bool),
              ) ??
              {
                'scanReminders': true,
                'treatmentReminders': true,
                'uvAlerts': true,
              },
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
              ? (json['createdAt'] as Timestamp).toDate()
              : (json['createdAt'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
                  : DateTime.now()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'skinType': skinType,
      'age': age,
      'allergies': allergies,
      'notifications': notifications,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? skinType,
    int? age,
    List<String>? allergies,
    Map<String, bool>? notifications,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      skinType: skinType ?? this.skinType,
      age: age ?? this.age,
      allergies: allergies ?? this.allergies,
      notifications: notifications ?? this.notifications,
      createdAt: createdAt,
    );
  }

  /// Display name fallback
  String get displayName => name ?? email ?? phone ?? 'User';

  /// Fitzpatrick skin type descriptions
  static const Map<String, String> skinTypes = {
    'I': 'Type I — Very fair, always burns',
    'II': 'Type II — Fair, burns easily',
    'III': 'Type III — Medium, sometimes burns',
    'IV': 'Type IV — Olive, rarely burns',
    'V': 'Type V — Brown, very rarely burns',
    'VI': 'Type VI — Dark brown/black, never burns',
  };
}
