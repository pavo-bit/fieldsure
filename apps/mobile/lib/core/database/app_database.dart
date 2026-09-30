import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class LocalTests extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get testNumber => text().nullable()(); // Assigned by server
  TextColumn get caseId => text().nullable()();
  TextColumn get sampleId => text().nullable()();
  TextColumn get operatorId => text()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get kitId => text()();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  TextColumn get result => text().nullable()();
  
  DateTimeColumn get clientCreatedAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();
  
  @override
  Set<Column> get primaryKey => {id};
}

class LocalTestKits extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get manufacturer => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get configurationVersion => text()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class LocalEvidence extends Table {
  TextColumn get id => text()(); // Image ID (UUID)
  TextColumn get testId => text().references(LocalTests, #id)(); // Foreign key to LocalTests
  TextColumn get localPath => text()(); // Path to the local image file
  TextColumn get imageHash => text()(); // SHA-256 hash
  TextColumn get qualityResult => text()(); // JSON string of ImageQualityResult
  IntColumn get imageWidth => integer()();
  IntColumn get imageHeight => integer()();
  TextColumn get deviceInfo => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('CAPTURED'))(); // CAPTURED, UPLOADING, SYNCED
  DateTimeColumn get capturedAt => dateTime()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  TextColumn get id => text()(); // UUID localOperationId
  TextColumn get testId => text().references(LocalTests, #id)();
  TextColumn get operationType => text()(); // CREATE_TEST, UPLOAD_IMAGE, PROCESS_TEST
  TextColumn get payload => text()(); // JSON
  TextColumn get fileReference => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  TextColumn get lastError => text().nullable()();
  TextColumn get idempotencyKey => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CaptureMetadata extends Table {
  TextColumn get id => text()();
  TextColumn get testId => text().references(LocalTests, #id)();
  DateTimeColumn get capturedAt => dateTime()();
  TextColumn get deviceId => text()();
  TextColumn get appVersion => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get altitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  TextColumn get exposureTime => text().nullable()();
  TextColumn get iso => text().nullable()();
  TextColumn get whiteBalance => text().nullable()();
  TextColumn get referenceCardVersion => text().nullable()();
  DateTimeColumn get reagentAddedAt => dateTime().nullable()();
  TextColumn get additionalMetadata => text().nullable()(); // JSON

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  LocalTests,
  LocalTestKits,
  LocalEvidence,
  SyncQueue,
  CaptureMetadata,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(localEvidence);
        }
        if (from < 3) {
          await m.createTable(syncQueue);
        }
        if (from < 4) {
          await m.createTable(captureMetadata);
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'fieldsure_db');
  }
}
