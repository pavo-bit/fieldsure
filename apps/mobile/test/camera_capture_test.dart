import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:fieldsure_mobile/core/database/app_database.dart';
import 'package:fieldsure_mobile/features/camera/data/evidence_repository.dart';
import 'package:fieldsure_mobile/features/camera/domain/image_quality_result.dart';
import 'package:fieldsure_mobile/core/network/sync_service.dart';

class FakeSyncService implements SyncService {
  @override
  Future<void> enqueueOperation({
    required String testId,
    required String operationType,
    required Map<String, dynamic> payload,
    String? fileReference,
    String? idempotencyKey,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;
  late EvidenceRepository evidenceRepository;
  late FakeSyncService fakeSyncService;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    fakeSyncService = FakeSyncService();
    evidenceRepository = EvidenceRepository(database, fakeSyncService);
  });

  tearDown(() async {
    await database.close();
  });

  group('EvidenceRepository & Camera Metadata Tests', () {
    test('calculateImageHash produces deterministic SHA-256', () async {
      final tempDir = Directory.systemTemp.createTempSync('fieldsure_test');
      final file = File('${tempDir.path}/test_image.jpg');
      await file.writeAsBytes([1, 2, 3, 4, 5]);

      final hash = await evidenceRepository.calculateImageHash(file.path);
      
      // Expected SHA-256 for [1, 2, 3, 4, 5]
      const expected = '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0';
      expect(hash, expected);
      
      file.deleteSync();
      tempDir.deleteSync();
    });

    test('saveCaptureMetadata saves to DB and updates Test state', () async {
      // Create a dummy test record first
      await database.into(database.localTests).insert(
        LocalTestsCompanion.insert(
          id: 'test-123',
          kitId: 'kit-123',
          operatorId: 'operator-123',
          status: const Value('DRAFT'),
          clientCreatedAt: DateTime.now(),
        ),
      );

      const quality = ImageQualityResult(
        isAcceptable: true,
        resolutionOk: true,
        brightnessOk: true,
        sharpnessOk: true,
        glareOk: true,
        decodable: true,
      );

      await evidenceRepository.saveCaptureMetadata(
        testId: 'test-123',
        localPath: '/fake/path/image.jpg',
        imageWidth: 1080,
        imageHeight: 1920,
        qualityResult: quality,
        imageHash: 'fakehash',
      );

      final evidences = await database.select(database.localEvidence).get();
      expect(evidences.length, 1);
      expect(evidences.first.testId, 'test-123');
      expect(evidences.first.imageHash, 'fakehash');
      expect(evidences.first.status, 'CAPTURED');

      final tests = await database.select(database.localTests).get();
      expect(tests.first.id, 'test-123');
      expect(tests.first.status, 'CAPTURED'); // State transitioned DRAFT -> CAPTURED
    });
  });

  group('ImageQualityResult State Machine & Verification', () {
    test('Unacceptable images report correct flags', () {
      const result = ImageQualityResult(
        isAcceptable: false,
        resolutionOk: false,
        brightnessOk: true,
        sharpnessOk: true,
        glareOk: true,
        decodable: true,
        errors: ['Resolution too low.'],
      );

      expect(result.isAcceptable, false);
      expect(result.errors.length, 1);
      expect(result.errors.first, 'Resolution too low.');
    });
  });
}
