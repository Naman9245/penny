import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:penny/data/db/tables.dart';
import 'package:penny/models/txn_enums.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Txns])
class AppDatabase extends _$AppDatabase {
  /// Opens `penny.sqlite` in the app's documents folder. Tests pass an
  /// in-memory executor instead.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'penny'));

  // To change the schema: bump this, add a step to [migration], then run
  // `dart run drift_dev make-migrations` so the new step gets a test.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}
