import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String id;
  final String name;
  final int age;
  final String linkCode;
  final DateTime linkCodeExpiresAt;
  final String? deviceUid;
  final String? deviceName;
  final DateTime? linkedAt;
  final DateTime? lastSeen;

  ChildModel({
    required this.id,
    required this.name,
    required this.age,
    required this.linkCode,
    required this.linkCodeExpiresAt,
    this.deviceUid,
    this.deviceName,
    this.linkedAt,
    this.lastSeen,
  });

  bool get isLinked => deviceUid != null && deviceUid!.isNotEmpty;

  bool get isCodeExpired => DateTime.now().isAfter(linkCodeExpiresAt);

  factory ChildModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? fallback;
      return fallback;
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ChildModel(
      id: id,
      name: map['name'] as String? ?? 'Child',
      age: (map['age'] as num?)?.toInt() ?? 0,
      linkCode: map['linkCode'] as String? ?? '',
      linkCodeExpiresAt: parseDate(
        map['linkCodeExpiresAt'],
        DateTime.now().add(const Duration(hours: 24)),
      ),
      deviceUid: map['deviceUid'] as String?,
      deviceName: map['deviceName'] as String?,
      linkedAt: parseNullableDate(map['linkedAt']),
      lastSeen: parseNullableDate(map['lastSeen']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'linkCode': linkCode,
      'linkCodeExpiresAt': Timestamp.fromDate(linkCodeExpiresAt),
      'deviceUid': deviceUid,
      'deviceName': deviceName,
      'linkedAt': linkedAt != null ? Timestamp.fromDate(linkedAt!) : null,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    };
  }

  ChildModel copyWith({
    String? name,
    int? age,
    String? linkCode,
    DateTime? linkCodeExpiresAt,
    String? deviceUid,
    String? deviceName,
    DateTime? linkedAt,
    DateTime? lastSeen,
  }) {
    return ChildModel(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      linkCode: linkCode ?? this.linkCode,
      linkCodeExpiresAt: linkCodeExpiresAt ?? this.linkCodeExpiresAt,
      deviceUid: deviceUid ?? this.deviceUid,
      deviceName: deviceName ?? this.deviceName,
      linkedAt: linkedAt ?? this.linkedAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
