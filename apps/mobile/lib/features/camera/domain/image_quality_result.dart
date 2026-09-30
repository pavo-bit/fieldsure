class ImageQualityResult {
  final bool isAcceptable;
  final bool resolutionOk;
  final bool brightnessOk;
  final bool sharpnessOk;
  final bool glareOk;
  final bool decodable;
  final List<String> warnings;
  final List<String> errors;

  const ImageQualityResult({
    required this.isAcceptable,
    required this.resolutionOk,
    required this.brightnessOk,
    required this.sharpnessOk,
    required this.glareOk,
    required this.decodable,
    this.warnings = const [],
    this.errors = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'isAcceptable': isAcceptable,
      'resolutionOk': resolutionOk,
      'brightnessOk': brightnessOk,
      'sharpnessOk': sharpnessOk,
      'glareOk': glareOk,
      'decodable': decodable,
      'warnings': warnings,
      'errors': errors,
    };
  }

  factory ImageQualityResult.fromJson(Map<String, dynamic> json) {
    return ImageQualityResult(
      isAcceptable: json['isAcceptable'] as bool,
      resolutionOk: json['resolutionOk'] as bool,
      brightnessOk: json['brightnessOk'] as bool,
      sharpnessOk: json['sharpnessOk'] as bool,
      glareOk: json['glareOk'] as bool,
      decodable: json['decodable'] as bool,
      warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      errors: (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }
}
