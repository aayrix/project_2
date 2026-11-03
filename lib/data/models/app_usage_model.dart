class AppUsageModel {
  final String packageName;
  final String appName;
  final String category;
  final int ms;

  AppUsageModel({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.ms,
  });

  factory AppUsageModel.fromMap(String packageName, Map<String, dynamic> map) {
    return AppUsageModel(
      packageName: packageName,
      appName: map['appName'] as String? ?? packageName,
      category: map['category'] as String? ?? 'other',
      ms: (map['ms'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'category': category,
      'ms': ms,
    };
  }

  AppUsageModel copyWith({
    String? packageName,
    String? appName,
    String? category,
    int? ms,
  }) {
    return AppUsageModel(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      category: category ?? this.category,
      ms: ms ?? this.ms,
    );
  }
}
