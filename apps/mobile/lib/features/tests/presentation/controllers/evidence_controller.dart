import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class EvidenceModel {
  final String id;
  final String testId;
  final String imageHash;
  final String recordHash;
  final String signature;
  final String verificationStatus;
  final String signedAt;

  EvidenceModel({
    required this.id,
    required this.testId,
    required this.imageHash,
    required this.recordHash,
    required this.signature,
    required this.verificationStatus,
    required this.signedAt,
  });

  factory EvidenceModel.fromJson(Map<String, dynamic> json) {
    return EvidenceModel(
      id: json['id'] as String,
      testId: json['testId'] as String,
      imageHash: json['imageHash'] as String,
      recordHash: json['recordHash'] as String,
      signature: json['signature'] as String,
      verificationStatus: json['verificationStatus'] as String? ?? 'UNKNOWN',
      signedAt: json['signedAt'] as String,
    );
  }
}

class VerificationResult {
  final bool verified;
  final String integrity;
  final String imageIntegrity;
  final String recordIntegrity;
  final String signature;
  
  VerificationResult({
    required this.verified,
    required this.integrity,
    required this.imageIntegrity,
    required this.recordIntegrity,
    required this.signature,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      verified: json['verified'] as bool,
      integrity: json['integrity'] as String,
      imageIntegrity: json['imageIntegrity'] as String,
      recordIntegrity: json['recordIntegrity'] as String,
      signature: json['signature'] as String,
    );
  }
}

final evidenceProvider = FutureProvider.family<EvidenceModel, String>((ref, testId) async {
  final api = ref.watch(apiClientProvider);
  
  try {
    // Try to get existing evidence
    final response = await api.dio.get('/tests/$testId/evidence');
    return EvidenceModel.fromJson(response.data['data']);
  } catch (e) {
    // If not found, create it
    final response = await api.dio.post('/tests/$testId/evidence', data: {});
    return EvidenceModel.fromJson(response.data['data']);
  }
});

class VerificationController extends StateNotifier<AsyncValue<VerificationResult?>> {
  final ApiClient _api;
  final String testId;

  VerificationController(this._api, this.testId) : super(const AsyncValue.data(null));

  Future<void> verify() async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.dio.post('/tests/$testId/verify', data: {});
      final result = VerificationResult.fromJson(response.data['data']);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final verificationControllerProvider = StateNotifierProvider.family<VerificationController, AsyncValue<VerificationResult?>, String>((ref, testId) {
  final api = ref.watch(apiClientProvider);
  return VerificationController(api, testId);
});
