class TestModel {
  final String id;
  final String? testNumber;
  final String? caseId;
  final String? sampleId;
  final String operatorId;
  final String? deviceId;
  final String kitId;
  final String status;
  final String? result;
  final num? confidence;
  final String? algorithmVersion;
  final String? modelVersion;
  final String? verificationStatus;
  final String clientCreatedAt;
  final String? startedAt;
  final String? completedAt;

  const TestModel({
    required this.id,
    this.testNumber,
    this.caseId,
    this.sampleId,
    required this.operatorId,
    this.deviceId,
    required this.kitId,
    required this.status,
    this.result,
    this.confidence,
    this.algorithmVersion,
    this.modelVersion,
    this.verificationStatus,
    required this.clientCreatedAt,
    this.startedAt,
    this.completedAt,
  });

  factory TestModel.fromJson(Map<String, dynamic> json) {
    String? verificationStatus;
    if (json['evidenceRecord'] != null) {
      verificationStatus = json['evidenceRecord']['verificationStatus'];
    }
    return TestModel(
      id: json['id'] as String? ?? '',
      testNumber: json['testNumber'] as String?,
      caseId: json['caseId'] as String?,
      sampleId: json['sampleId'] as String?,
      operatorId: json['operatorId'] as String? ?? (json['operator']?['operatorId'] ?? ''),
      deviceId: json['deviceId'] as String?,
      kitId: json['kitId'] as String? ?? '',
      status: json['status'] as String? ?? 'DRAFT',
      result: json['result'] as String?,
      confidence: json['classification']?['confidence'] as num? ?? json['confidence'] as num?,
      algorithmVersion: json['classification']?['algorithmVersion'] as String? ?? json['algorithmVersion'] as String?,
      modelVersion: json['classification']?['modelVersion'] as String? ?? json['modelVersion'] as String?,
      verificationStatus: verificationStatus,
      clientCreatedAt: json['clientCreatedAt'] as String? ?? DateTime.now().toIso8601String(),
      startedAt: json['startedAt'] as String?,
      completedAt: json['completedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'testNumber': testNumber,
      'caseId': caseId,
      'sampleId': sampleId,
      'operatorId': operatorId,
      'deviceId': deviceId,
      'kitId': kitId,
      'status': status,
      'result': result,
      'confidence': confidence,
      'algorithmVersion': algorithmVersion,
      'modelVersion': modelVersion,
      'verificationStatus': verificationStatus,
      'clientCreatedAt': clientCreatedAt,
      'startedAt': startedAt,
      'completedAt': completedAt,
    };
  }

  TestModel copyWith({
    String? id,
    String? testNumber,
    String? caseId,
    String? sampleId,
    String? operatorId,
    String? deviceId,
    String? kitId,
    String? status,
    String? result,
    num? confidence,
    String? algorithmVersion,
    String? modelVersion,
    String? verificationStatus,
    String? clientCreatedAt,
    String? startedAt,
    String? completedAt,
  }) {
    return TestModel(
      id: id ?? this.id,
      testNumber: testNumber ?? this.testNumber,
      caseId: caseId ?? this.caseId,
      sampleId: sampleId ?? this.sampleId,
      operatorId: operatorId ?? this.operatorId,
      deviceId: deviceId ?? this.deviceId,
      kitId: kitId ?? this.kitId,
      status: status ?? this.status,
      result: result ?? this.result,
      confidence: confidence ?? this.confidence,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      modelVersion: modelVersion ?? this.modelVersion,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
