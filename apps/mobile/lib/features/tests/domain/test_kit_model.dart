class TestKitModel {
  final String id;
  final String code;
  final String name;
  final String manufacturer;
  final String? description;
  final bool active;
  final String configurationVersion;

  const TestKitModel({
    required this.id,
    required this.code,
    required this.name,
    required this.manufacturer,
    this.description,
    this.active = true,
    required this.configurationVersion,
  });

  factory TestKitModel.fromJson(Map<String, dynamic> json) {
    return TestKitModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      description: json['description'] as String?,
      active: json['active'] as bool? ?? true,
      configurationVersion: json['configurationVersion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'manufacturer': manufacturer,
      'description': description,
      'active': active,
      'configurationVersion': configurationVersion,
    };
  }
}
