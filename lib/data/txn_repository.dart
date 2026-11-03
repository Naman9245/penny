import 'package:drift/drift.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/analysis_totals.dart';
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
    String? dedupeKey,
    bool? payeeIsPerson,
  }) async {
    _checkAmount(amountPaise);
    final id = _uuid.v7();
    final now = _clock();
    await _db
        .into(_txns)
        .insert(
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
            dedupeKey: Value(dedupeKey),
            payeeIsPerson: Value(payeeIsPerson),
          ),
        );
    return id;
  }

  /// The live entry imported from the SMS with this fingerprint, if any.
  Future<Txn?> findByDedupeKey(String dedupeKey) {
    final query = _db.select(_txns)
      ..where((t) => t.dedupeKey.equals(dedupeKey) & t.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  /// Rewrites an entry. [tag] and [payeeIsPerson] are required so an edit
  /// can't drop them by accident.
  Future<void> update(
    String id, {
    required int amountPaise,
    required TxnType type,
    required String categoryId,
    required DateTime occurredAt,
    String? merchant,
    required TxnTag? tag,
    required bool? payeeIsPerson,
  }) async {
    _checkAmount(amountPaise);
    await (_db.update(_txns)..where((t) => t.id.equals(id))).write(
      TxnsCompanion(
        amountPaise: Value(amountPaise),
        type: Value(type),
        categoryId: Value(categoryId),
        merchant: Value(merchant),
        occurredAt: Value(occurredAt),
        tag: Value(tag),
        payeeIsPerson: Value(payeeIsPerson),
        updatedAt: Value(_clock()),
        dirty: const Value(true),
      ),
    );
  }

  /// Sets the user's own tag on each entry at once, for "I need this" on a
  /// habit and for its undo. Null clears it back to Penny's pick.
  Future<void> setTags(Map<String, TxnTag?> tags) {
    final now = _clock();
    return _db.batch((batch) {
      for (final MapEntry(key: id, value: tag) in tags.entries) {
        batch.update(
          _txns,
          TxnsCompanion(
            tag: Value(tag),
            updatedAt: Value(now),
            dirty: const Value(true),
          ),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  Future<void> softDelete(String id) => _setDeletedAt(id, _clock());

  Future<void> restore(String id) {
    return _db.transaction(() async {
      final row = await (_db.select(
        _txns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final key = row?.dedupeKey;
      // If the same SMS was imported again meanwhile, that entry keeps the
      // fingerprint and this one comes back without it.
      final clash = key != null && await findByDedupeKey(key) != null;
      await (_db.update(_txns)..where((t) => t.id.equals(id))).write(
        TxnsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(_clock()),
          dirty: const Value(true),
          dedupeKey: clash ? const Value(null) : const Value.absent(),
        ),
      );
    });
  }

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

  /// Entries from [from] up to, not including, [to], newest first.
  Stream<List<Txn>> watchBetween(DateTime from, DateTime to) {
    final query = _db.select(_txns)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.occurredAt.isBiggerOrEqualValue(from) &
            t.occurredAt.isSmallerThanValue(to),
      )
      ..orderBy(_newestFirst);
    return query.watch();
  }

  /// When the first live entry happened, or null before there is one.
  Stream<DateTime?> watchFirstOccurredAt() {
    final first = _txns.occurredAt.min();
    final query = _db.selectOnly(_txns)
      ..addColumns([first])
      ..where(_txns.deletedAt.isNull());
    return query.map((row) => row.read(first)).watchSingle();
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

  /// Totals and entry counts per category for the month containing [month],
  /// biggest first.
  Stream<List<CategoryTotal>> watchCategoryTotals(DateTime month) {
    final total = _txns.amountPaise.sum();
    final count = _txns.id.count();
    final query = _db.selectOnly(_txns)
      ..addColumns([_txns.categoryId, _txns.type, total, count])
      ..where(_inMonth(_txns, month))
      ..groupBy([_txns.categoryId, _txns.type]);
    return query.watch().map((rows) {
      final totals = [
        for (final row in rows)
          CategoryTotal(
            categoryId: row.read(_txns.categoryId)!,
            type: row.readWithConverter(_txns.type)!,
            totalPaise: row.read(total) ?? 0,
            count: row.read(count) ?? 0,
          ),
      ];
      totals.sort((a, b) => b.totalPaise.compareTo(a.totalPaise));
      return totals;
    });
  }

  /// Spent and got for each of the [months] months ending with the one
  /// containing [endMonth], oldest first. Months with no entries are zero.
  Stream<List<MonthTotals>> watchMonthlyTotals(
    DateTime endMonth, {
    int months = 6,
  }) {
    final end = nextMonth(monthStart(endMonth));
    final start = DateTime(end.year, end.month - months);
    final query = _db.selectOnly(_txns)
      ..addColumns([_txns.type, _txns.amountPaise, _txns.occurredAt])
      ..where(
        _txns.deletedAt.isNull() &
            _txns.occurredAt.isBiggerOrEqualValue(start) &
            _txns.occurredAt.isSmallerThanValue(end),
      );
    return query.watch().map((rows) {
      final spent = List.filled(months, 0);
      final got = List.filled(months, 0);
      for (final row in rows) {
        final at = row.read(_txns.occurredAt)!;
        final i = (at.year - start.year) * 12 + at.month - start.month;
        final paise = row.read(_txns.amountPaise)!;
        switch (row.readWithConverter(_txns.type)) {
          case TxnType.debit:
            spent[i] += paise;
          case TxnType.credit:
            got[i] += paise;
          case null:
            break;
        }
      }
      return [
        for (var i = 0; i < months; i++)
          MonthTotals(
            month: DateTime(start.year, start.month + i),
            spentPaise: spent[i],
            gotPaise: got[i],
          ),
      ];
    });
  }

  Future<void> _setDeletedAt(String id, DateTime? at) async {
    await (_db.update(_txns)..where((t) => t.id.equals(id))).write(
      TxnsCompanion(
        deletedAt: Value(at),
        updatedAt: Value(_clock()),
        dirty: const Value(true),
      ),
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
