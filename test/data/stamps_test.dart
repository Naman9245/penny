import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';

// The database moves a row's stamp forward on every edit made here, so a
// later edit always wins when phones sync.
void main() {
  final start = DateTime(2026, 11, 5, 10);
  late DateTime now;
  late AppDatabase db;

  setUp(() {
    now = start;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  TxnRepository txns() => TxnRepository(db, clock: () => now);

  Future<String> add() => txns().add(
    amountPaise: 25000,
    type: TxnType.debit,
    categoryId: 'food',
    occurredAt: start,
  );

  Future<void> edit(String id, int paise) async {
    final txn = (await txns().findById(id))!;
    await txns().update(
      id,
      amountPaise: paise,
      type: txn.type,
      categoryId: txn.categoryId,
      occurredAt: txn.occurredAt,
      merchant: txn.merchant,
      tag: txn.tag,
      payeeIsPerson: txn.payeeIsPerson,
    );
  }

  Future<DateTime> stampOf(String id) async {
    final row = await (db.select(
      db.txns,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.updatedAt;
  }

  test('edits within the same second still move forward', () async {
    final id = await add();
    await edit(id, 30000);
    expect(await stampOf(id), start.add(const Duration(seconds: 1)));
    await edit(id, 35000);
    expect(await stampOf(id), start.add(const Duration(seconds: 2)));

    // A delete and its undo too.
    await txns().softDelete(id);
    await txns().restore(id);
    expect(await stampOf(id), start.add(const Duration(seconds: 4)));
  });

  test('with the clock behind, an edit lands after the one it replaces', () {
    return () async {
      final id = await add();
      now = start.subtract(const Duration(minutes: 5));
      await edit(id, 30000);
      expect(await stampOf(id), start.add(const Duration(seconds: 1)));
    }();
  });

  test('a later clock keeps its own time', () async {
    final id = await add();
    now = start.add(const Duration(minutes: 5));
    await edit(id, 30000);
    expect(await stampOf(id), now);
  });

  test('the note moves forward too, written over in one go', () async {
    final prefs = PrefsRepository(db, clock: () => now);
    await prefs.setNote('Student');
    await prefs.setNote('Student in a PG');
    final note = await (db.select(
      db.prefs,
    )..where((p) => p.name.equals(PrefsRepository.noteName))).getSingle();
    expect(note.updatedAt, start.add(const Duration(seconds: 1)));
  });
}
