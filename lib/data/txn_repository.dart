import 'package:drift/drift.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/month_summary.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:uuid/uuid.dart';

/// Every read and write of transactions. Soft-deleted rows never leave this
/// class.
class TxnRepository {
  TxnRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _uuid = Uuid();

  $TxnsTable get _txns => _db.txns;

  /// Saves a new entry and returns its id.
  Future<String> add({
    required int amountPaise,
    required TxnType type,
    required String categoryId,
    required DateTime occurredAt,
    String? merchant,
    TxnSource source = TxnSource.manual,
  }) async {
    _checkAmount(amountPaise);
    final id = _uuid.v7();
    final now = _clock();
    await _db.into(_txns).insert(
          TxnsCompanion.insert(
            id: id,
            amountPaise: amountPaise,
            type: type,
            categoryId: categoryId,
            merchant: Value(merchant),
            occurredAt: occurredAt,
            source: source,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    required int amountPaise,
    required TxnType type,
    required String categoryId,
    required DateTime occurredAt,
    String? merchant,
  }) async {
    _checkAmount(amountPaise);
    await (_db.update(_txns)..where((t) => t.id.equals(id))).write(
      TxnsCompanion(
        amountPaise: Value(amountPaise),
        type: Value(type),
        categoryId: Value(categoryId),
        merchant: Value(merchant),
        occurredAt: Value(occurredAt),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> softDelete(String id) => _setDeletedAt(id, _clock());

  Future<void> restore(String id) => _setDeletedAt(id, null);

  Future<Txn?> findById(String id) {
    final query = _db.select(_txns)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  /// Entries in the month containing [month], newest first.
  Stream<List<Txn>> watchMonth(DateTime month) {
    final query = _db.select(_txns)
      ..where((t) => _inMonth(t, month))
      ..orderBy(_newestFirst);
    return query.watch();
  }

  Stream<List<Txn>> watchRecent({int limit = 5}) {
    final query = _db.select(_txns)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy(_newestFirst)
      ..limit(limit);
    return query.watch();
  }

  Stream<MonthSummary> watchMonthSummary(DateTime month) {
    final total = _txns.amountPaise.sum();
    final query = _db.selectOnly(_txns)
      ..addColumns([_txns.type, total])
      ..where(_inMonth(_txns, month))
      ..groupBy([_txns.type]);
    return query.watch().map((rows) {
      var spent = 0;
      var got = 0;
      for (final row in rows) {
        final sum = row.read(total) ?? 0;
        switch (row.readWithConverter(_txns.type)) {
          case TxnType.debit:
            spent = sum;
          case TxnType.credit:
            got = sum;
          case null:
            break;
        }
      }
      return MonthSummary(spentPaise: spent, gotPaise: got);
    });
  }

  Future<void> _setDeletedAt(String id, DateTime? at) async {
    await (_db.update(_txns)..where((t) => t.id.equals(id))).write(
      TxnsCompanion(deletedAt: Value(at), updatedAt: Value(_clock())),
    );
  }

  static final _newestFirst = <OrderClauseGenerator<$TxnsTable>>[
    (t) => OrderingTerm.desc(t.occurredAt),
    (t) => OrderingTerm.desc(t.createdAt),
  ];

  static Expression<bool> _inMonth($TxnsTable t, DateTime month) {
    final start = monthStart(month);
    return t.deletedAt.isNull() &
        t.occurredAt.isBiggerOrEqualValue(start) &
        t.occurredAt.isSmallerThanValue(nextMonth(start));
  }

  static void _checkAmount(int paise) {
    if (paise <= 0) {
      throw ArgumentError.value(paise, 'amountPaise', 'must be positive');
    }
  }
}
