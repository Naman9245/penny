import 'package:drift/drift.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/analysis_totals.dart';
import 'package:penny/models/month_summary.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/combine_math.dart';
import 'package:penny/services/money_kinds.dart';
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

  /// Makes the live entries [ids] one entry for their total
  /// ([combinationOf]), and deletes them the usual way, so backup carries
  /// it and [uncombine] can bring them back. Their SMS stay known, so one
  /// read again never brings an entry back. The new entry's id, or null
  /// when they can't be combined.
  Future<String?> combine(List<String> ids) => _db.transaction(() async {
    final txns = await (_db.select(
      _txns,
    )..where((t) => t.id.isIn(ids) & t.deletedAt.isNull())).get();
    if (txns.length != ids.length) return null;
    final combined = combinationOf(txns);
    if (combined == null) return null;
    final id = await add(
      amountPaise: combined.amountPaise,
      type: combined.type,
      categoryId: combined.categoryId,
      occurredAt: combined.occurredAt,
      merchant: combined.merchant,
      source: combined.source,
      payeeIsPerson: combined.payeeIsPerson,
    );
    final now = _clock();
    for (final txn in txns) {
      await _setDeletedAt(txn.id, now, combinedInto: id);
    }
    return id;
  });

  /// Undoes [combine]: deletes the entry [combinedId] and brings back
  /// [ids].
  Future<void> uncombine(String combinedId, List<String> ids) =>
      _db.transaction(() async {
        await softDelete(combinedId);
        for (final id in ids) {
          await restore(id);
          await (_db.update(_txns)..where((t) => t.id.equals(id))).write(
            TxnsCompanion(
              combinedInto: const Value(null),
              updatedAt: Value(_clock()),
              dirty: const Value(true),
            ),
          );
        }
      });

  /// The entries [combinedId] was made of, oldest first. Empty for one
  /// that wasn't combined, or was before parts were kept.
  Stream<List<Txn>> watchParts(String combinedId) =>
      (_db.select(_txns)
            ..where((t) => t.combinedInto.equals(combinedId))
            ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
          .watch();

  /// How many entries each combined entry was made of, by its id.
  Stream<Map<String, int>> watchCombinedCounts() {
    final count = _txns.id.count();
    final query = _db.selectOnly(_txns)
      ..addColumns([_txns.combinedInto, count])
      ..where(_txns.combinedInto.isNotNull())
      ..groupBy([_txns.combinedInto]);
    return query.watch().map(
      (rows) => {
        for (final row in rows) row.read(_txns.combinedInto)!: row.read(count)!,
      },
    );
  }

  /// Takes [combinedId] apart: deletes it and brings back what it was made
  /// of. Their ids, for [recombine].
  Future<List<String>> splitApart(String combinedId) =>
      _db.transaction(() async {
        final parts = await (_db.select(
          _txns,
        )..where((t) => t.combinedInto.equals(combinedId))).get();
        final ids = [for (final part in parts) part.id];
        await uncombine(combinedId, ids);
        return ids;
      });

  /// Undoes [splitApart]: [combinedId] back, made of [ids] again.
  Future<void> recombine(String combinedId, List<String> ids) =>
      _db.transaction(() async {
        await restore(combinedId);
        final now = _clock();
        for (final id in ids) {
          await _setDeletedAt(id, now, combinedInto: combinedId);
        }
      });

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

  /// Every live entry, oldest first: what an export holds.
  Future<List<Txn>> everything() {
    final query = _db.select(_txns)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.occurredAt),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.get();
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

  /// The month's spending, income and investing, counted the one way every
  /// screen counts them.
  Stream<MonthSummary> watchMonthSummary(DateTime month) =>
      _watchSums(month).map((sums) {
        final totals = MoneyTotals.fromSums(sums);
        return MonthSummary(
          spentPaise: totals.spentPaise,
          gotPaise: totals.gotPaise,
          investedPaise: totals.investedPaise,
          leftPaise: totals.leftPaise,
        );
      });

  /// Totals and entry counts per category for the month containing [month],
  /// biggest first.
  Stream<List<CategoryTotal>> watchCategoryTotals(DateTime month) =>
      _watchSums(month).map(categoryTotalsOf);

  /// The month's live entries summed by type and category.
  Stream<List<CategorySum>> _watchSums(DateTime month) {
    final total = _txns.amountPaise.sum();
    final count = _txns.id.count();
    final query = _db.selectOnly(_txns)
      ..addColumns([_txns.type, _txns.categoryId, total, count])
      ..where(_inMonth(_txns, month))
      ..groupBy([_txns.type, _txns.categoryId]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            type: row.readWithConverter(_txns.type)!,
            categoryId: row.read(_txns.categoryId)!,
            paise: row.read(total) ?? 0,
            count: row.read(count) ?? 0,
          ),
      ],
    );
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
      ..addColumns([
        _txns.type,
        _txns.categoryId,
        _txns.amountPaise,
        _txns.occurredAt,
      ])
      ..where(
        _txns.deletedAt.isNull() &
            _txns.occurredAt.isBiggerOrEqualValue(start) &
            _txns.occurredAt.isSmallerThanValue(end),
      );
    return query.watch().map((rows) {
      final byMonth = [for (var i = 0; i < months; i++) <CategorySum>[]];
      for (final row in rows) {
        final at = row.read(_txns.occurredAt)!;
        byMonth[(at.year - start.year) * 12 + at.month - start.month].add((
          type: row.readWithConverter(_txns.type)!,
          categoryId: row.read(_txns.categoryId)!,
          paise: row.read(_txns.amountPaise)!,
          count: 1,
        ));
      }
      return [
        for (final (i, sums) in byMonth.indexed)
          if (MoneyTotals.fromSums(sums) case final totals)
            MonthTotals(
              month: DateTime(start.year, start.month + i),
              spentPaise: totals.spentPaise,
              gotPaise: totals.gotPaise,
            ),
      ];
    });
  }

  Future<void> _setDeletedAt(
    String id,
    DateTime? at, {
    String? combinedInto,
  }) async {
    await (_db.update(_txns)..where((t) => t.id.equals(id))).write(
      TxnsCompanion(
        deletedAt: Value(at),
        updatedAt: Value(_clock()),
        dirty: const Value(true),
        combinedInto: combinedInto == null
            ? const Value.absent()
            : Value(combinedInto),
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
